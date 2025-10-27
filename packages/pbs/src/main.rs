use crate::args::CliArgs;
use crate::auth::authenticate;
use crate::youtube::{
    bind_stream_to_broadcast, create_broadcast, create_stream_key, destroy_broadcast,
    stop_broadcast,
};
use clap::Parser;
use rusqlite::{Connection};
use crate::obs::{set_obs_stream_key};

mod args;
mod auth;
mod ui;
mod utils;
mod youtube;
mod obs;

#[tokio::main]
async fn main() {
    let args = CliArgs::parse();

    utils::set_working_dir();

    let db = Connection::open("db.sqlite").expect("Failed to open database");

    db.execute(
        "
        CREATE TABLE IF NOT EXISTS broadcasts (
            id TEXT PRIMARY KEY,
            stream_key TEXT NOT NULL
        )
    ",
        (),
    )
    .expect("Failed to create broadcasts table");

    match args.command {
        args::Subcommands::Auth { force } => {
            println!("Auth command called with force: {}", force);
            authenticate().await;
        }
        args::Subcommands::Start {
            title,
            visibility,
        } => {
            println!(
                "Start command called with title: '{}' and visibility: {:?}",
                title.as_deref().unwrap_or("N/A"),
                visibility
            );

            let title_ref = title.as_deref();

            let stream = create_stream_key(title_ref)
                .await
                .expect("Couldn't create stream key");

            let broadcast = create_broadcast(title_ref, visibility).await.expect("Couldn't create broadcast");

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

            db.execute(
                "
                INSERT INTO broadcasts (id, stream_key) VALUES (?1, ?2)
            ",
                (&broadcast_id, &stream_key),
            )
                .expect("Failed to insert broadcast into database");
            
            println!(
                "Go to https://studio.youtube.com/video/{}/livestreaming to view your stream",
                &broadcast_id
            );
        }
        args::Subcommands::Stop { delete, visibility } => {
            println!(
                "Stop command called with delete: {} and visibility: {:?}",
                &delete, &visibility
            );

            let mut stmt = db
                .prepare("SELECT id FROM broadcasts")
                .expect("Failed to prepare statement");

            let broadcast_ids = stmt
                .query_map([], |row| row.get(0))
                .expect("Failed to query broadcasts")
                .collect::<Result<Vec<String>, _>>()
                .expect("Failed to collect broadcast IDs");

            for broadcast_id in broadcast_ids {
                stop_broadcast(&broadcast_id, &visibility).await;

                if delete {
                    destroy_broadcast(&broadcast_id)
                        .await
                        .expect("Failed to delete broadcast on YouTube");

                    db.execute("DELETE FROM broadcasts WHERE id = ?1", (&broadcast_id,))
                        .expect("Failed to delete broadcast from database");
                }
            }
        }
    }
}
