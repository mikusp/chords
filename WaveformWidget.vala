using Cairo;
using Gdk;

public class WaveformWidget : Gtk.DrawingArea {
    public float[,] audioData {
        set {
            var i = 0;
            var end = false;
            while (!end) {
                var peak = 0.0f;
                for (var j = i * samplesPerPixel; j < (i+1) * samplesPerPixel; ++j) {
                    if (value.length[1] == j) {
                        end = true;
                        break;
                    }

                    if (value[0, j] > peak)
                        peak = value[0, j];
                }
                peaks.insert_val(i, peak);
                ++i;
            }
        }
    }
    public double zoom {get; set; default = 0;}
    private int samplesPerPixel {get; set; default = 80;}
    private GLib.Array<float?> peaks;

    public WaveformWidget() {
        this.peaks = new GLib.Array<float?>();
        this.draw.connect(this.renderWaveform);
        this.add_events(EventMask.BUTTON_PRESS_MASK | EventMask.BUTTON_RELEASE_MASK |
            EventMask.BUTTON_MOTION_MASK | EventMask.EXPOSURE_MASK);
    }

    private bool renderWaveform(Cairo.Context c) {
        if (peaks.length == 0)
            return false;

        var maxPeakHeight = this.get_allocated_height() / 2.0;
        var verticalMiddle = maxPeakHeight;

        c.set_line_width(1.0);
        c.set_source_rgb(0.0, 0.0, 1.0);

        var peaksLength = peaks.length;
        var sspZoom = Math.pow(2, this.zoom);

        for (int i = 0; i < this.get_allocated_width(); ++i) {
            var maxFromRange = 0.0f;
            for (int j = (int)(sspZoom * i); j < (int)(sspZoom * (i+1)) && j < peaksLength; j++) {
                if (peaks.index(j) > maxFromRange)
                    maxFromRange = peaks.index(j);
            }

            c.move_to(i + 0.5, verticalMiddle - maxFromRange * maxPeakHeight);
            c.line_to(i + 0.5, verticalMiddle + maxFromRange * maxPeakHeight);
            c.stroke();
        }

        c.set_source_rgb(0.0, 0.0, 0.0);
        c.move_to(0, verticalMiddle);
        c.line_to(this.get_allocated_width(), verticalMiddle);
        c.stroke();

        return false;
    }

}
