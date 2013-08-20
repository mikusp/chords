using Cairo;
using Gdk;
using Gdk;

public class WaveformWidget : Gtk.DrawingArea {
    public float[,] audioData {private get; owned set;}
    public int pointsPerPixel {get; set; default = 1000;}
    private Gee.HashMap<int, ArrayWrapper> peaksCache;

    private class ArrayWrapper : GLib.Object {
        public GLib.Array<float?> negatives;
        public GLib.Array<float?> positives;
        public uint length {
            get {
                return negatives.length;
            }
            set {
                negatives.set_size(value);
                positives.set_size(value);
            }
        }
        public ArrayWrapper() {
            negatives = new GLib.Array<float?>();
            positives = new GLib.Array<float?>();
        }
    }

    public WaveformWidget() {
        this.peaksCache = new Gee.HashMap<int, ArrayWrapper>();
        this.draw.connect(this.renderWaveform);
        this.add_events(EventMask.BUTTON_PRESS_MASK | EventMask.BUTTON_RELEASE_MASK |
            EventMask.BUTTON_MOTION_MASK | EventMask.EXPOSURE_MASK);
    }

    private bool renderWaveform(Cairo.Context c) {
        if (audioData.length[0] == 0)
            return false;

        if (peaksCache.has_key(pointsPerPixel)) {
            if (peaksCache.get(pointsPerPixel).length < this.get_allocated_width()) {
                this.partialPopulateCache();
            }
        }
        else {
            this.populateCache();
        }

        // now cache definitely has needed values

        var maxPeakHeight = this.get_allocated_height() / 2.0;
        var verticalMiddle = maxPeakHeight;
        var peaks = peaksCache.get(pointsPerPixel);

        c.set_line_width(1.0);
        c.set_source_rgb(0.0, 0.0, 1.0);

        for (int i = 0; i < this.get_allocated_width(); ++i) {
            c.move_to(i + 0.5, verticalMiddle - peaks.negatives.index(i) * maxPeakHeight);
            c.line_to(i + 0.5, verticalMiddle - peaks.positives.index(i) * maxPeakHeight);
            c.stroke();
        }

        c.set_source_rgb(0.0, 0.0, 0.0);
        c.move_to(0, verticalMiddle);
        c.line_to(this.get_allocated_width(), verticalMiddle);
        c.stroke();

        return false;
    }

    private void populateCache() {
        var wrapper = new ArrayWrapper();

        for (uint i = 0; i < this.get_allocated_width(); ++i) {
            var negativePeak = 0.0;
            var positivePeak = 0.0;

            for (int j = 0; j < pointsPerPixel; ++j) {
                if (i * pointsPerPixel + j > audioData.length[1])
                    break;

                if (audioData[0,i * pointsPerPixel + j] < negativePeak)
                    negativePeak = audioData[0, i * pointsPerPixel + j];
                if (audioData[0, i * pointsPerPixel + j] > positivePeak)
                    positivePeak = audioData[0, i * pointsPerPixel + j];
            }

            wrapper.negatives.append_val((float)negativePeak);
            wrapper.positives.append_val((float)positivePeak);
        }

        peaksCache.set(pointsPerPixel, wrapper);
    }

    private void partialPopulateCache() {
        var wrapper = peaksCache.get(pointsPerPixel);
        var from = wrapper.length;

        for (uint i = from; i < this.get_allocated_width(); ++i) {
            var negativePeak = 0.0;
            var positivePeak = 0.0;

            for (int j = 0; j < pointsPerPixel; ++j) {
                if (i * pointsPerPixel + j > audioData.length[1])
                    break;

                if (audioData[0,i * pointsPerPixel + j] < negativePeak)
                    negativePeak = audioData[0, i * pointsPerPixel + j];
                if (audioData[0, i * pointsPerPixel + j] > positivePeak)
                    positivePeak = audioData[0, i * pointsPerPixel + j];
            }

            wrapper.negatives.append_val((float)negativePeak);
            wrapper.positives.append_val((float)positivePeak);
        }
    }
}
