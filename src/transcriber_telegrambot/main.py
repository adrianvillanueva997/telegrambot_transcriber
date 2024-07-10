import asyncio
import os
import uuid
from pathlib import Path
from shutil import ExecError

import anyio
from loguru import logger
from prometheus_client import start_http_server
from telegram import File, Update
from telegram.ext import (
    Application,
    CommandHandler,
    ContextTypes,
    MessageHandler,
    filters,
)


async def help_command(update: Update, _: ContextTypes.DEFAULT_TYPE) -> None:
    """Send a message when the command /help is issued."""
    if update.message:
        await update.message.reply_text("Help!")


async def transcribe(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Transcribres the user message."""
    if (
        update.message
        and update.message.voice
        and hasattr(update.message.voice, "file_id")
    ):
        voice_file: File = await context.bot.get_file(update.message.voice.file_id)
        session_id: uuid.UUID = uuid.uuid4()
        audio_name = f"{session_id!s}.ogg"
        output_name = f"{session_id!s}.txt"
        logger.info(update.message.voice)
        await voice_file.download_to_drive(audio_name)
        try:
            # Create the audio file
            process = await asyncio.create_subprocess_exec(
                "vosk-transcriber",
                "-l",
                "es",
                "-i",
                audio_name,
                "-o",
                output_name,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
            await process.wait()
            async with await anyio.open_file(output_name) as file:
                content = await file.read()
                try:
                    await update.message.reply_text(
                        text=content,
                        reply_to_message_id=update.message.id,
                    )
                except Exception as e:
                    logger.error(e)

        except ExecError as e:
            logger.error(e)
        finally:
            # Clean up
            Path(audio_name).unlink(missing_ok=True)
            Path(output_name).unlink(missing_ok=True)


def main() -> None:
    """Start the bot."""
    # Create the Application and pass it your bot's token.
    application = Application.builder().token(os.environ["BOT_TOKEN"]).build()

    # on different commands - answer in Telegram
    application.add_handler(CommandHandler("help", help_command))

    # on non command i.e message - echo the message on Telegram
    application.add_handler(MessageHandler(~filters.COMMAND, transcribe))

    # Run the bot until the user presses Ctrl-C
    application.run_polling()


if __name__ == "__main__":
    start_http_server(2112)
    logger.info("Bot running!")
    main()
