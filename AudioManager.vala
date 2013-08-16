using Gst;

public class AudioManager : GLib.Object {
    private Pipeline pipeline = new Gst.Pipeline("pipeline");
    public ClockTime duration {
        get {
            ClockTime val;
            pipeline.query_duration(Format.TIME, out val);
            return val;
        }
        private set {
            duration = value;
        }
        default = CLOCK_TIME_NONE;
    }

    public int64 position {
        get {
            int64 val;
            pipeline.query_position(Format.TIME, out val);
            return val;
        }
        private set {
            position = value;
        }
    }

    public double volume {
        get {
            double val;
            pipeline.get_by_name("volume").get("volume", out val);
            return val;
        }
        set {
            pipeline.get_by_name("volume").set("volume", value);
        }
    }

    public int speed {get; set; default = 100;}

    private bool _speedActive;
    public bool speedActive {
        get {
            return _speedActive;
        }
        set {
            if (value)
                setPlaybackSpeed((double)speed / 100);
            else
                setPlaybackSpeed(1.0);

            _speedActive = value;
        }
    }

    public double pitch {get; set; default = 0;}

    private bool _pitchActive;
    public bool pitchActive {
        get {
            return _pitchActive;
        }
        set {
            if (value)
                setPitch(GLib.Math.pow(2, pitch / 12));
            else
                setPitch(1);

            _pitchActive = value;
        }
    }

    private void setPitch(double pitch) {
        pipeline.get_by_name("pitch").set("pitch", pitch);
    }

    private void setPlaybackSpeed(double speed) {
        pipeline.get_by_name("pitch").set("tempo", speed);
    }

    public AudioManager() {
        this.notify["speed"].connect(() => {
            if (speedActive)
                setPlaybackSpeed((double)this.speed / 100);
        });

        this.notify["pitch"].connect(() => {
            if (pitchActive)
                setPitch(GLib.Math.pow(2, pitch / 12));
        });

        var bus = pipeline.get_bus();
        bus.add_signal_watch();

        bus.message["error"].connect(this.errorMessageHandler);

        var src = Gst.ElementFactory.make("filesrc", "source");
        var dec = Gst.ElementFactory.make("decodebin", "decoder");
        var conv = Gst.ElementFactory.make("audioconvert", "converter");
        var pitch = Gst.ElementFactory.make("pitch", "pitch");
        var vol = Gst.ElementFactory.make("volume", "volume");
        var sink = Gst.ElementFactory.make("pulsesink", "sink");
        dec.pad_added.connect(this.padAdded);
        pipeline.add_many(src, dec, conv, pitch, vol, sink, null);
        src.link(dec);
        conv.link_many(pitch, vol, sink, null);
    }

    ~AudioProvider() {
        if (pipeline.current_state != Gst.State.NULL)
            pipeline.set_state(State.NULL);
    }

    public void play() {
        pipeline.set_state(State.PLAYING);
    }

    public void pause() {
        pipeline.set_state(State.PAUSED);
    }

    public void stop() {
        pipeline.set_state(State.READY);
    }

    public bool updateRequired() {
        return pipeline.current_state >= State.PAUSED;
    }

    private void padAdded(Element decodebin, Pad pad) {
        var convpad = pipeline.get_by_name("converter").get_static_pad("sink");
        if (convpad.is_linked())
            return;

        pad.link(convpad);
    }

    public void setFileName(string fileName) {
        pipeline.get_by_name("source").set_property("location", fileName);
        pipeline.set_state(State.READY);
    }

    private void errorMessageHandler(Gst.Bus bus, Message message) {
        Error error;
        string debug_info;

        message.parse_error(out error, out debug_info);
        warning("Error received from %s: %s\n", message.src.name, error.message);
        warning("Debug info: %s\n", debug_info);

        pipeline.set_state(State.READY);
    }

}
