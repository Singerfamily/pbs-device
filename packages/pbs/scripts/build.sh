deno compile \
    --allow-net \
    --allow-read \
    --allow-env \
    --allow-run \
    --allow-sys \
    --allow-write \
    --unstable-temporal \
    --unstable-kv \
    --output ./bin/pbs \
    cli/main.ts
