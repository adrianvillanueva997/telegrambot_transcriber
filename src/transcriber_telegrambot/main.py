import asyncio
import json
import os
import shutil
import tempfile
import uuid
from dataclasses import dataclass, field
from pathlib import Path
from threading import Lock
from typing import TYPE_CHECKING, ClassVar

import anyio
from loguru import logger
from prometheus_client import start_http_server
from pydub import AudioSegment
from telegram import Update
from telegram.ext import (
    Application,
    CommandHandler,
    ContextTypes,
    MessageHandler,
    filters,
)
from vosk import KaldiRecognizer, Model

if TYPE_CHECKING:
    from telegram import File


_transcribe_semaphore = asyncio.Semaphore(4)


@dataclass
class Audio:
    session_id: uuid.UUID = field(default_factory=uuid.uuid4)
    EXTENSION: str = field(default="ogg")
    TIMEOUT: int = field(default=120)
    _tmpdir: Path = field(default_factory=lambda: Path(tempfile.mkdtemp()))

    _model: ClassVar[Model | None] = None
    _model_lock: ClassVar[Lock] = Lock()

    def __del__(self) -> None:
        if self._tmpdir.exists():
            shutil.rmtree(self._tmpdir, ignore_errors=True)

    @property
    def name(self) -> str:
        return str(self._tmpdir / f"{self.session_id}.{self.EXTENSION}")

    @classmethod
    def _get_model(cls) -> Model:
        if cls._model is None:
            with cls._model_lock:
                if cls._model is None:
                    cls._model = Model(lang="es")
        return cls._model

    async def transcribe(self) -> str:
        def _run() -> str:
            audio = AudioSegment.from_file(self.name, format=self.EXTENSION)
            audio = audio.set_frame_rate(16000).set_channels(1).set_sample_width(2)
            raw_data = audio.raw_data

            model = self._get_model()
            rec = KaldiRecognizer(model, 16000.0)
            rec.SetWords(True)

            results = []
            offset = 0
            chunk_size = 4000
            while offset < len(raw_data):
                chunk = raw_data[offset : offset + chunk_size]
                offset += chunk_size
                if rec.AcceptWaveform(chunk):
                    part = json.loads(rec.Result())
                    results.append(part)
            final = json.loads(rec.FinalResult())
            results.append(final)

            return "\n".join(part["text"] for part in results if part.get("text"))

        async with _transcribe_semaphore:
            return await asyncio.wait_for(
                asyncio.to_thread(_run),
                timeout=self.TIMEOUT,
            )


async def help_command(update: Update, _: ContextTypes.DEFAULT_TYPE) -> None:
    """Send a message when the command /help is issued."""
    if update.message:
        await update.message.reply_text("Help!")


async def transcribe(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Transcribes a voice message."""
    if not (update.message and update.message.voice):
        return

    audio = Audio()
    voice_file: File = await context.bot.get_file(update.message.voice.file_id)
    for attempt in range(3):
        try:
            await voice_file.download_to_drive(audio.name)
            break
        except Exception as e:
            logger.warning(f"Download attempt {attempt + 1} failed: {e}")
            if attempt < 2:
                await asyncio.sleep(2**attempt)
    else:
        logger.error("Download failed after 3 attempts")
        return

    if not await anyio.Path(audio.name).exists():
        logger.error(f"Downloaded file not found: {audio.name}")
        return

    try:
        text = await audio.transcribe()
        logger.info(
            f"Transcribed voice ({update.message.from_user.username}): {text or '[empty]'}",
        )
        if not text:
            return
        await update.message.reply_text(
            text=text,
            reply_to_message_id=update.message.id,
        )
    except Exception as e:
        logger.error(f"Transcription failed: {e}")
    finally:
        await anyio.Path(audio.name).unlink(missing_ok=True)


def main() -> None:
    """Start the bot."""
    start_http_server(2112)
    logger.info("Bot running!")
    application = Application.builder().token(os.environ["BOT_TOKEN"]).build()

    application.add_handler(CommandHandler("help", help_command))

    application.add_handler(MessageHandler(~filters.COMMAND, transcribe))

    application.run_polling()


if __name__ == "__main__":
    main()
