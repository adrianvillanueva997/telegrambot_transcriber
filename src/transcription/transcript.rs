use std::path::Path;
use std::process::Command;

pub const AUDIO: &str = "audio.ogg";

pub async fn transcribe_voice_message() -> Result<(), Box<dyn std::error::Error>> {
    if !audio_file_exists() {
        panic!("Audio file does not exist")
    }
    let command = Command::new("vosk-transcriber")
        .arg("-l")
        .arg("es")
        .arg("-i")
        .arg(AUDIO)
        .arg("-o")
        .arg("output.txt")
        .output();
    match command {
        Ok(_) => (),
        Err(err) => panic!("Error running command: {}", err),
    };

    Ok(())
}

/// .
fn audio_file_exists() -> bool {
    Path::new(AUDIO).exists()
}
