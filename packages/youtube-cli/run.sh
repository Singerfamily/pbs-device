set -eou pipefail

function cleanup {
    echo "Performing cleanup..."
    # Add your cleanup commands here
    cargo run -- stop -d
}
trap cleanup EXIT

cargo run -- start -t "TEST STREAM" -v private

obs --profile Default