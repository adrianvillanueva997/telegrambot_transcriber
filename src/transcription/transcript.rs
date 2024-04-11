use std::path::Path;
use std::process::Command;

use rust_embed::RustEmbed;
use vosk::{Model, Recognizer};

pub const AUDIO: &str = "audio.ogg";

#[derive(RustEmbed)]
#[folder = "models"]
struct Models;

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

fn test() {
    let samples = [100, -2, 700, 30, 4, 5];
    // let model_path = Models::get("vosk-model-small-es-0.42.zip");
    let model_path = "vosk-model-small-es-0.42.zip";

    let model = Model::new(model_path).unwrap();
    let mut recognizer = Recognizer::new(&model, 16000.0).unwrap();

    recognizer.set_max_alternatives(10);
    recognizer.set_words(true);
    recognizer.set_partial_words(true);

    for sample in samples.chunks(100) {
        recognizer.accept_waveform(sample);
        println!("{:#?}", recognizer.partial_result());
    }

    println!("{:#?}", recognizer.final_result().multiple().unwrap());
}
