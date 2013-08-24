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
            this.setSizeRequest();
        }
    }
    public double zoom {get; set; default = 0;}
    // TODO zooming should not move the position of a waveform
    private int samplesPerPixel {get; set; default = 80;}
    private GLib.Array<float?> peaks;

    public WaveformWidget() {
        this.peaks = new GLib.Array<float?>();
        this.draw.connect(this.renderWaveform);
        this.notify["zoom"].connect(this.setSizeRequest);
        this.add_events(EventMask.BUTTON_PRESS_MASK | EventMask.BUTTON_RELEASE_MASK |
            EventMask.BUTTON_MOTION_MASK | EventMask.EXPOSURE_MASK);
    }

    private bool renderWaveform(Cairo.Context c) {
        Gdk.Rectangle rect;
        var res = Gdk.cairo_get_clip_rectangle(c, out rect);
        // what if res == false? TODO

        if (peaks.length == 0) {
            // no data, nothing to do
            drawBackground(c, rect);
            drawZeroLevelLine(c);

            return false;
        }

        var maxPeakHeight = this.get_allocated_height() / 2.0;
        var verticalMiddle = maxPeakHeight;

        var peaksLength = peaks.length;
        var expZoom = Math.pow(2, this.zoom);

        drawBackground(c, rect);

        c.set_line_width(1.0);
        c.set_source_rgb(0.698, 0.506, 0.376);

        for (int i = rect.x; i < rect.x + rect.width; ++i) {
            var maxFromRange = 0.0f;
            for (int j = (int)(expZoom * i); j < (int)(expZoom * (i+1)) && j < peaksLength; j++) {
                if (peaks.index(j) > maxFromRange)
                    maxFromRange = peaks.index(j);
            }

            c.move_to(i + 0.5, verticalMiddle - maxFromRange * maxPeakHeight);
            c.line_to(i + 0.5, verticalMiddle + maxFromRange * maxPeakHeight);
            c.stroke();
        }

        drawZeroLevelLine(c);

        return false;
    }

    private void drawBackground(Cairo.Context c, Gdk.Rectangle rect) {
        c.rectangle(rect.x, rect.y, rect.width, rect.height);
        c.set_source_rgb(1.0, 0.843, 0.737);
        c.fill();
    }

    private void drawZeroLevelLine(Cairo.Context c) {
        var verticalMiddle = this.get_allocated_height() / 2.0;

        c.set_line_width(0.5);
        c.set_source_rgb(0.0, 0.0, 0.0);
        c.move_to(0, verticalMiddle);
        c.line_to(this.get_allocated_width(), verticalMiddle);
        c.stroke();
    }

    private void setSizeRequest() {
        var newWidth = (int)(this.peaks.length / Math.pow(2, this.zoom));
        this.set_size_request(newWidth, -1);
    }

}
