use crate::args::Visibility;
use crate::auth::authenticate;
use chrono::prelude::*;
use google_youtube3::api::*;

// Creation
pub async fn create_stream_key(title: Option<&str>) -> Result<LiveStream, google_youtube3::Error> {
    let yt = authenticate().await;

    let mut req = LiveStream::default();
    
    req.cdn = Some(CdnSettings {
        ingestion_type: Some("rtmp".to_string()),
        resolution: Some("variable".to_string()),
        frame_rate: Some("variable".to_string()),
        ..Default::default()
    });

    req.snippet = Some(LiveStreamSnippet {
        title: title
            .map(|t| t.to_string())
            .or(Some("Sacrament Meeting".to_string())),
        ..Default::default()
    });

    req.content_details = Some(LiveStreamContentDetails {
        is_reusable: Some(false),
        ..Default::default()
    });

    let result = yt.live_streams().insert(req).doit().await;

    match result {
        Ok((_, live_stream)) => {
            if let Some(ingestion_info) = &live_stream
                .cdn
                .as_ref()
                .and_then(|cdn| cdn.ingestion_info.as_ref())
            {
                println!(
                    "Stream Key: {}",
                    ingestion_info.stream_name.as_deref().unwrap_or("N/A")
                );
            } else {
                println!("No ingestion info available.");
            }
            Ok(live_stream)
        }
        Err(e) => {
            eprintln!("Error creating stream key: {:?}", e);
            Err(e)
        }
    }
}

pub fn extract_stream_key(stream: &LiveStream) -> &str {
    stream
        .cdn
        .as_ref()
        .and_then(|cdn| cdn.ingestion_info.as_ref())
        .and_then(|info| info.stream_name.as_ref())
        .unwrap()
} 

pub async fn create_broadcast(
    title: Option<&str>,
    visibility: Option<Visibility>,
) -> google_youtube3::Result<LiveBroadcast> {
    let yt = authenticate().await;

    let mut req = LiveBroadcast::default();

    req.snippet = Some(LiveBroadcastSnippet {
        title: title
            .map(|t| t.to_string())
            .or(Some("Sacrament Meeting".to_string())),
        scheduled_start_time: Some(
            Utc::now()
                .with_minute(0)
                .unwrap()
                .with_second(0)
                .unwrap()
                .with_nanosecond(0)
                .unwrap()
                + chrono::Duration::hours(1),
        ),
        scheduled_end_time: Some(
            Utc::now()
                .with_minute(0)
                .unwrap()
                .with_second(0)
                .unwrap()
                .with_nanosecond(0)
                .unwrap()
                + chrono::Duration::hours(2),
        ),
        ..Default::default()
    });

    req.status = Some(LiveBroadcastStatus {
        privacy_status: Some(visibility.unwrap_or(Visibility::Unlisted).to_string()),
        ..Default::default()
    });

    req.content_details = Some(LiveBroadcastContentDetails {
        enable_auto_start: Some(true),
        enable_auto_stop: Some(true),
        enable_dvr: Some(false),
        ..Default::default()
    });

    let result = yt.live_broadcasts().insert(req).doit().await;

    match result {
        Ok((_, broadcast)) => {
            println!(
                "Broadcast created with ID: {}",
                broadcast.id.as_deref().unwrap_or("N/A")
            );
            Ok(broadcast)
        }
        Err(e) => {
            eprintln!("Error creating broadcast: {:?}", e);
            Err(e)
        }
    }
}

pub async fn bind_stream_to_broadcast(
    broadcast: &LiveBroadcast,
    stream: &LiveStream,
) -> google_youtube3::Result<LiveBroadcast> {
    let yt = authenticate().await;
    
    let broadcast_id = broadcast.id.as_deref().expect("Broadcast id is None");
    let stream_id = stream.id.as_deref().expect("Stream id is None");

    let result = yt
        .live_broadcasts()
        .bind(broadcast_id, &vec!["id".into()])
        .stream_id(stream_id)
        .doit()
        .await;
    
    let stream_key = extract_stream_key(&stream);

    match result {
        Ok((_, broadcast)) => {
            println!(
                "Successfully bound stream {} to broadcast {}",
                stream_key, broadcast_id
            );
            Ok(broadcast)
        }
        Err(e) => {
            eprintln!(
                "Error binding stream {} to broadcast {}: {:?}",
                stream_key, broadcast_id, e
            );
            Err(e)
        }
    }
}

// Destruction
// pub async fn destroy_stream_key(stream_id: &String) -> google_youtube3::Result<()> {
//     let yt = authenticate().await;
//
//     let result = yt.live_streams().delete(stream_id).doit().await;
//
//     match result {
//         Ok((_)) => {
//             println!("Successfully deleted stream {}", stream_id);
//             Ok(())
//         }
//         Err(e) => {
//             eprintln!("Error deleting stream {}: {:?}", stream_id, e);
//             Err(e)
//         }
//     }
// }

pub async fn destroy_broadcast(broadcast_id: &String) -> Result<(), google_youtube3::Error> {
    let yt = authenticate().await;

    let result = yt.live_broadcasts().delete(broadcast_id).doit().await;

    match result {
        Ok(_) => {
            println!("Successfully deleted broadcast {}", broadcast_id);
            Ok(())
        }
        Err(e) => {
            eprintln!("Error deleting broadcast {}: {:?}", broadcast_id, e);
            Err(e)
        }
    }
}

pub async fn stop_broadcast(broadcast_id: &String, visibility: &Option<Visibility>) {
    let yt = authenticate().await;

    let mut req = LiveBroadcast::default();
    
    req.id = Some(broadcast_id.to_string());

    req.status = Some(LiveBroadcastStatus {
        privacy_status: Some(
            visibility
                .to_owned()
                .unwrap_or(Visibility::Unlisted)
                .to_string(),
        ),
        // privacy_status: &visibility.unwrap().to_string()
        ..Default::default()
    });
    
    yt.live_broadcasts()
        .update(req)
        .doit()
        .await
        .expect("Failed to update broadcast");
}
