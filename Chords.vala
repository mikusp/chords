using Gtk;
using Gst;

public class Chords : Gtk.Application {
    private AudioManager am;
    private Builder builder;
    private float[] rawAudio;

    private Scale slider;

    public Chords() {
        GLib.Object(application_id: "com.mgw.chords",
            flags: GLib.ApplicationFlags.FLAGS_NONE);

        am = new AudioManager();
    }

    public override void activate() {
        builder = new Builder();
        try {
            builder.add_from_file("chords.ui");
            connectSignals();

            this.add_window((Window)builder.get_object("window"));
        } catch (GLib.Error e) {
            stderr.printf("Error while loading UI file\n");
        }
    }

    public bool refreshUI() {
        if (!am.updateRequired())
            return true;

        slider.set_range(0, (double)am.duration / Gst.SECOND);
        slider.set_value((double)am.position / Gst.SECOND);

        return true;
    }

    public void speedChanged(Range range) {
        am.speed = (int)range.get_value();
    }

    public void speedToggled(ToggleButton tb) {
        am.speedActive = tb.get_active();
    }

    public void connectSignals() {
        (builder.get_object("closeMenuItem") as ImageMenuItem).
            activate.connect(Gtk.main_quit);

        (builder.get_object("openFileMenuItem") as ImageMenuItem).
            activate.connect(this.openFile);

        var volumeSlider = builder.get_object("volumeSlider") as Gtk.Scale;
        volumeSlider.value_changed.connect(this.volumeChanged);
        volumeSlider.set_range(0, 1);
        volumeSlider.set_value(0.5);

        slider = builder.get_object("slider") as Scale;

        (builder.get_object("openButton") as Button).clicked.connect(this.openFile);

        (builder.get_object("playButton") as Button).clicked.connect(am.play);

        (builder.get_object("pauseButton") as Button).clicked.connect(am.pause);

        (builder.get_object("stopButton") as Button).clicked.connect(am.stop);

        (builder.get_object("slowToggleButton") as ToggleButton).toggled.connect(this.speedToggled);

        var speedSlider = builder.get_object("speedSlider") as Scale;
        speedSlider.set_range(10, 100);
        speedSlider.set_value(100);
        speedSlider.value_changed.connect(this.speedChanged);

        (builder.get_object("pitchToggleButton") as ToggleButton).toggled.connect(this.pitchToggled);

        var pitchSlider = builder.get_object("pitchSlider") as Scale;
        pitchSlider.set_adjustment(new Adjustment(0.0, -12.0, 13.0, 1.0, 1.0, 1.0));
        pitchSlider.value_changed.connect(this.pitchChanged);

        Timeout.add(50, this.refreshUI);
    }

    private void volumeChanged(Range range) {
        am.volume = range.get_value();
    }

    private void pitchChanged(Range range) {
        am.pitch = range.get_value();
    }

    private void pitchToggled(ToggleButton tb) {
        am.pitchActive = tb.get_active();
    }

    public void openFile() {
        var fc = new Gtk.FileChooserDialog("Open music file", (Gtk.Window)builder.get_object("window"), Gtk.FileChooserAction.OPEN,
            Gtk.Stock.CANCEL, Gtk.ResponseType.CANCEL,
            Gtk.Stock.OPEN, Gtk.ResponseType.ACCEPT);

        var filter = new Gtk.FileFilter();
        filter.add_mime_type("audio/*");
        fc.set_filter(filter);

        if (fc.run() == Gtk.ResponseType.ACCEPT) {
            am.setFileName(fc.get_filename());
            var fs = new FileSource(fc.get_filename());
            this.rawAudio = fs.get_f32_le();
        }
        fc.close();
    }

    static int main(string[] args) {
        Gst.init(ref args);
        var app = new Chords();
        return app.run(args);
    }
}
