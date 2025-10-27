pub async fn set_obs_stream_key(stream_key: &str, profile: String) {
    // Path to the OBS configuration file
    let home_dir = std::env::var("HOME").unwrap_or_else(|_| ".".to_string());

    let obs_cfg = std::env::var("OBS_CFG_PATH")
        .unwrap_or_else(|_| format!("{}/.config/obs-studio", home_dir));

    let obs_config_path = format!("{}/basic/profiles/{}/service.json", obs_cfg, profile);

    let obs_config = format!(
        r#"{{
        "settings":{{
            "bwtest":false,
            "key":"{}",
            "server":"rtmps://a.rtmps.youtube.com:443/live2",
            "service":"YouTube - RTMPS"
        }},
        "type":"rtmp_common"
    }}"#,
        stream_key
    );

    std::fs::create_dir_all(format!("{}/basic/profiles/{}", obs_cfg, profile))
        .expect("Failed to create OBS config directory");
    std::fs::write(&obs_config_path, obs_config).expect("Failed to write OBS config file");
    println!("OBS stream key set successfully in {}", obs_config_path);
}
