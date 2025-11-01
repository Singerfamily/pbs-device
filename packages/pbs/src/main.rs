use std::fs::{File, remove_file};

use crate::args::CliArgs;
use crate::auth::authenticate;
use crate::obs::set_obs_stream_key;
use crate::youtube::{
    bind_stream_to_broadcast, create_broadcast, create_stream_key, destroy_broadcast,
    stop_broadcast,
};
use clap::Parser;
use serde::{Deserialize, Serialize};

use serde_json::{from_reader, to_writer};
use std::io::{BufReader};

mod args;
mod auth;
mod obs;
mod ui;
mod utils;
mod youtube;

#[derive(Serialize, Deserialize)]
struct Broadcast {
    id: String,
    key: String,
}

#[tokio::main]
async fn main() {
    let args = CliArgs::parse();

    utils::set_working_dir();

    match args.command {
        args::Subcommands::Auth { force } => {
            println!("Auth command called with force: {}", force);
            authenticate().await;
        }
        args::Subcommands::Start { title, visibility } => {
            println!(
                "Start command called with title: '{}' and visibility: {:?}",
                title.as_deref().unwrap_or("N/A"),
                visibility
            );

            let title_ref = title.as_deref();

            let stream = create_stream_key(title_ref)
                .await
                .expect("Couldn't create stream key");

            let broadcast = create_broadcast(title_ref, visibility)
                .await
                .expect("Couldn't create broadcast");

            let stream_key = stream
                .cdn
                .as_ref()
                .and_then(|cdn| cdn.ingestion_info.as_ref())
                .and_then(|info| info.stream_name.as_ref())
                .unwrap();

            let broadcast_id = broadcast.id.as_ref().unwrap();

            bind_stream_to_broadcast(&broadcast, &stream)
                .await
                .expect("Failed to bind stream to broadcast");

            set_obs_stream_key(&stream_key, String::from("Untitled")).await;

            // Open a file to write to
            let file = File::create("broadcast.json").expect("Failed to create broadcast.json");

            // Serialize the struct and write it to the file
            let _ = to_writer(
                file,
                &Broadcast {
                    id: broadcast_id.to_string(),
                    key: stream_key.to_string(),
                },
            );

            // let file = File::create("broadcast.json").expect("Couldn't create broadcast.json file");
            // let broadcast_info = Broadcast {
            //     id: broadcast_id.to_string(),
            //     key: stream_key.to_string(),
            // };
            // serde_json::to_writer_pretty(file, &broadcast_info)
            //     .expect("Couldn't write broadcast info to file");

            println!(
                "Go to https://studio.youtube.com/video/{}/livestreaming to view your stream",
                &broadcast_id
            );
        }
        args::Subcommands::Stop { delete, visibility } => {
            let file = File::open("broadcast.json").expect("Couldn't open broadcast.json file");
            let reader = BufReader::new(file);
            let data: Broadcast = from_reader(reader).expect("failed to parse broadcast.json");

            stop_broadcast(&data.id, &visibility).await;

            if delete {
                let _ = destroy_broadcast(&data.id).await;
            }

            remove_file("broadcast.json").expect("Failed to delete broadcast.json file");

            println!(
                "Stop command called with delete: {} and visibility: {:?}",
                &delete, &visibility
            );
        }
    }
}
