extern crate google_youtube3 as youtube3;
extern crate hyper;
use youtube3::{YouTube, hyper_util, yup_oauth2};

use hyper_rustls::HttpsConnector;
use hyper_util::client::legacy::connect::HttpConnector;
use std::fs;
use std::path::Path;

const CREDENTIALS_FILE: &str = "credentials.json";
const TOKEN_FILE: &str = "token.json";
const SCOPES: &[&str] = &[
    "https://www.googleapis.com/auth/youtube",
    "https://www.googleapis.com/auth/youtube.force-ssl",
    "https://www.googleapis.com/auth/youtube.upload",
];

pub async fn authenticate() -> YouTube<HttpsConnector<HttpConnector>> {
    let secret: yup_oauth2::ApplicationSecret = {
        let cred_path = Path::new(CREDENTIALS_FILE);
        if !cred_path.exists() {
            panic!("Credentials file not found: {}", CREDENTIALS_FILE);
        }
        let secret_json = fs::read_to_string(cred_path).expect("Failed to read credentials file");
        serde_json::from_str(&secret_json).expect("Failed to parse credentials file")
    };

    let auth = yup_oauth2::InstalledFlowAuthenticator::builder(
        secret,
        yup_oauth2::InstalledFlowReturnMethod::HTTPPortRedirect(8000),
    )
    .persist_tokens_to_disk(TOKEN_FILE)
    .build()
    .await
    .unwrap();

    // token(<scopes>) is the one important function of this crate; it does everything to
    // obtain a token that can be sent e.g. as Bearer token.
    match auth.token(SCOPES).await {
        Ok(_) => println!("Client authenticated successfully."),
        Err(e) => println!("error: {:?}", e),
    }

    let client = hyper_util::client::legacy::Client::builder(hyper_util::rt::TokioExecutor::new())
        .build(
            hyper_rustls::HttpsConnectorBuilder::new()
                .with_native_roots()
                .unwrap()
                .https_or_http()
                .enable_http1()
                .build(),
        );

    YouTube::new(client, auth)
}
