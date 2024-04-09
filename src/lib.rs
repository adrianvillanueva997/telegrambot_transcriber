use std::convert::Infallible;

use log::error;
use std::error::Error;
use teloxide::net::Download;
use teloxide::payloads::SendMessageSetters;
use teloxide::requests::Requester;
use teloxide::types::{Message, Voice};
use teloxide::update_listeners::UpdateListener;
use teloxide::Bot;
use tokio::fs;
use transcription::transcript::AUDIO;

mod transcription;

pub async fn parse_voice_messages(bot: &Bot, message: &Message, voice_message: &Voice) {
    let file = bot.get_file(voice_message.file.clone().id).await.unwrap();
    let mut dst = fs::File::create(AUDIO).await.unwrap();
    bot.download_file(&file.path, &mut dst).await.unwrap();
    if transcription::transcript::transcribe_voice_message()
        .await
        .is_err()
    {
        bot.send_message(message.chat.id, "No he podido transcribir eso :V")
            .reply_to_message_id(message.id)
            .await
            .unwrap();
    } else {
        let output = fs::read_to_string("output.txt").await.unwrap();
        bot.send_message(message.chat.id, output)
            .reply_to_message_id(message.id)
            .await
            .unwrap();
    }
}

pub async fn handle_messages(bot: &Bot, msg: &Message) -> Result<(), Box<dyn Error>> {
    match Some(msg) {
        Some(msg) if msg.voice().is_some() => {
            parse_voice_messages(bot, msg, msg.voice().unwrap()).await;
        }

        Some(_) => (),
        None => (),
    };
    Ok(())
}

/// Parse messages from the bot.
pub async fn parse_messages(bot: Bot, listener: impl UpdateListener<Err = Infallible> + Send) {
    teloxide::repl_with_listener(
        bot,
        |bot, msg| async move {
            if let Err(err) = handle_messages(&bot, &msg).await {
                error!("Error processing text messages: {}", err);
            }
            Ok(())
        },
        listener,
    )
    .await;
}
