deno run \
    --allow-net \
    --allow-read \
    --allow-env \
    --allow-run \
    --allow-sys \
    --allow-write \
    --unstable-temporal \
    --unstable-kv \
    cli/main.ts $@
