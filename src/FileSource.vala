using Gst;
using Gst.App;
using Gst.Base;

/*
* class FileSource
* Loads a file and converts it to raw audio array.
* get_f32_le() returns array containing floats
* ranging from -1 to 1, get_s32_le returns array
* with 32-bit signed ints.
*
* TODO:
* - no error handling
* - reads a file in an inner loop blocking thread
*/

public class FileSource : GLib.Object {
    private Gst.Pipeline pipeline {get; set;}
    private Gst.Element audioconv {get; set;}
    private Gst.Base.Adapter adapter {get; set;}
    private MainLoop loop {get; set;}

    /*
    * path - absolute path to file
    */
    public FileSource(string path) {
        pipeline = new Gst.Pipeline("pipeline");
        var uridecodebin = Gst.ElementFactory.make("uridecodebin", "uridecodebin");
        this.audioconv = Gst.ElementFactory.make("audioconvert", "audioconvert");
        dynamic Gst.Element appsink = Gst.ElementFactory.make("appsink", "appsink");

        var bus = pipeline.get_bus();
        bus.add_signal_watch();
        bus.message["error"].connect(this.errorMessageHandler);
        bus.message["eos"].connect(this.eosMessageHandler);

        var escapedPath = "file://" + GLib.Uri.escape_string(path, "/", true);
        uridecodebin.set_property("uri", escapedPath);
        uridecodebin.pad_added.connect(this.padAdded);

        appsink.caps = Gst.Caps.from_string(
                    "audio/x-raw, format=F32LE, channels=2");

        appsink.set_property("sync", false);
        appsink.set_property("drop", false);
        appsink.set_property("max-buffers", 10);
        appsink.set_property("emit-signals", true);
        appsink.new_sample.connect(this.newSample);

        pipeline.add_many(uridecodebin, audioconv, appsink);
        audioconv.link(appsink);

        pipeline.set_state(Gst.State.PAUSED);

        this.adapter = new Gst.Base.Adapter();
        this.loop = new GLib.MainLoop();
        loop.run();
    }

    public float[,] get_f32_le() {
        var length = this.adapter.available();
        float[,] result = new float[2,length / 4];
        var data = this.adapter.take(length);
        var br = new Gst.Base.ByteReader(data);

        for (int i = 0; i < length / 8; ++i) {
            float temp;
            br.get_float32_le(out temp);
            result[0, i] = temp;
            br.get_float32_le(out temp);
            result[1, i] = temp;
        }

        return result;
    }

    public int32[] get_s32_le() {
        var length = adapter.available();
        int32[] result = {};
        var br = new Gst.Base.ByteReader(this.adapter.take(length));

        for (int i = 0; i < length / 4; ++i) {
            int32 temp;
            br.get_int32_le(out temp);
            result += temp;
        }

        return result;
    }

    private void padAdded(Element el, Pad pad) {
        var convpad = this.audioconv.get_static_pad("sink");
        if (!convpad.is_linked()) {
            pad.link(convpad);
        }

        this.pipeline.set_state(Gst.State.PLAYING);
    }

    private Gst.FlowReturn newSample(Gst.Element el) {
        var sink = (Gst.App.Sink) el;
        var buf = sink.pull_sample().get_buffer();

        this.adapter.push(buf);

        return Gst.FlowReturn.OK;
    }

    private void eosMessageHandler(Gst.Bus bus, Gst.Message message) {
        loop.quit();
        this.pipeline.set_state(Gst.State.NULL);
    }

    private void errorMessageHandler(Gst.Bus bus, Message message) {
        Error error;
        string debug_info;

        message.parse_error(out error, out debug_info);
        warning("Error received from %s: %s\n", message.src.name, error.message);
        warning("Debug info: %s\n", debug_info);
    }
}

