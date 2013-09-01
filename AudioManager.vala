using Gst;

public class AudioManager : GLib.Object {
    private Pipeline pipeline = new Gst.Pipeline("pipeline");
    public ClockTime duration {
        get {
            ClockTime val;
            pipeline.query_duration(Format.TIME, out val);
            return val;
        }
    }

    public int64 position {
        get {
            int64 val;
            pipeline.query_position(Format.TIME, out val);
            return songTime(val);
        }
        set {
            var pos = pipeTime(value);
            pipeline.seek_simple(Format.TIME, SeekFlags.FLUSH, pos);
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

    private double _speed = 1.0;
    public double speed {
        get {
            return _speed;
        }
        set {
            var pos = this.position;
            _speed = value;
            if (this.speedActive) {
                this.setPlaybackSpeed(this.speed);
                this.position = pos;
            }
        }
    }

    private bool _speedActive = false;
    public bool speedActive {
        get {
            return _speedActive;
        }
        set {
            var pos = this.position;
            _speedActive = value;
            if (value)
                this.setPlaybackSpeed(this.speed);
            else
                this.setPlaybackSpeed(1.0);
            this.position = pos;
        }
    }

    private double _pitch = 0;
    public double pitch {
        get {
            return _pitch;
        }
        set {
            _pitch = value;
            if (this.pitchActive)
                this.setPitch(Math.exp2(this.pitch / 12));
        }
    }

    private bool _pitchActive;
    public bool pitchActive {
        get {
            return _pitchActive;
        }
        set {
            _pitchActive = value;
            if (value)
                setPitch(Math.exp2(pitch / 12));
            else
                setPitch(1);
        }
    }

    private int64 songTime(int64 pipe_time) {
        double result = pipe_time;
        if (this.speedActive)
            result *= this.speed;

        return Math.llrint(result);
    }

    private int64 pipeTime(int64 song_time) {
        double result = song_time;
        if (this.speedActive)
            result /= this.speed;

        return Math.llrint(result);
    }

    private void setPitch(double pitch) {
        pipeline.get_by_name("pitch").set("pitch", pitch);
    }

    private void setPlaybackSpeed(double speed) {
        pipeline.get_by_name("pitch").set("tempo", speed);
    }

    public AudioManager() {
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

    ~AudioManager() {
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
