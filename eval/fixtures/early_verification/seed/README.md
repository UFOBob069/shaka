# Parcel stream

Deliver newline-delimited JSON records to a callback. The `id` of each complete
record is delivered once; an incomplete suffix waits for the next chunk.

`Receiver#receive` is the transport entry point. `LineDecoder` holds partial input.
The command-line adapter accepts one transport chunk per argument:

```sh
ruby bin/receive '{"id":"a"}
' '{"id":"b"}
'
```

Run the suite with `ruby -Itest test/line_decoder_test.rb`.
The receiver invokes the calback in arrival order.
