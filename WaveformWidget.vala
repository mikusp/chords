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
    private int samplesPerPixel {get; set; default = 80;}
    private GLib.Array<float?> peaks;
    private bool selection {get; set; default = false;}
    private bool click {get; set; default = false;}
    private bool move {get; set; default = false;}
    private bool leftExpand {get; set; default = false;}
    private bool rightExpand {get; set; default = false;}
    private double clickPosition {get; set; default = 0.0;}
    private double lastPointerPos {get; set;}
    private int startingSample {get; set;}
    private int endingSample {get; set;}

    public WaveformWidget() {
        this.peaks = new GLib.Array<float?>();
        this.draw.connect(this.renderWaveform);
        this.notify["zoom"].connect(this.setSizeRequest);
        this.add_events(EventMask.BUTTON_PRESS_MASK | EventMask.BUTTON_RELEASE_MASK |
            EventMask.BUTTON_MOTION_MASK | EventMask.EXPOSURE_MASK |
            EventMask.POINTER_MOTION_HINT_MASK |
            EventMask.POINTER_MOTION_MASK);
        this.event.connect(this.eventHandler);
    }

    private bool eventHandler(Gdk.Event e) {
        switch (e.type) {
        case Gdk.EventType.BUTTON_PRESS: {
            if (this.get_window().get_cursor() != null) {
                if (this.get_window().get_cursor().cursor_type == Gdk.CursorType.SB_H_DOUBLE_ARROW)
                    this.move = true;
            }
            else
                this.click = true;

            this.clickPosition = e.button.x;
            break;
        }
        case Gdk.EventType.BUTTON_RELEASE: {
            if (Math.fabs(e.button.x - this.clickPosition) <= 2) {
                this.selection = false;
            }
            this.click = false;
            this.move = false;
            break;
        }
        case Gdk.EventType.MOTION_NOTIFY: {
            setDirectionalCursor(e.motion.x);

            if (this.move) {
                var distance = Math.llrint(e.motion.x - this.lastPointerPos);
                var diff = pixelToPeakIndex(distance);
                this.startingSample += diff;
                this.endingSample += diff;
            }

            if (this.click && Math.fabs(e.motion.x - this.clickPosition) >= 5) {
                this.selection = true;

                if (e.motion.x > this.clickPosition) {
                    this.startingSample = pixelToPeakIndex(this.clickPosition);
                    this.endingSample = pixelToPeakIndex(e.motion.x);
                }
                else {
                    this.startingSample = pixelToPeakIndex(e.motion.x);
                    this.endingSample = pixelToPeakIndex(this.clickPosition);
                }
            }
            this.lastPointerPos = e.motion.x;
            break;
        }
        default:
            break;
        }
        this.queue_draw();
        return false;
    }

    private void setDirectionalCursor(double x) {
        Cursor c = null;

        if (this.selection) {
            if (Math.fabs(x - peakIndexToPixel(this.startingSample)) <= 8) {
                c = new Cursor.for_display(Gdk.Display.get_default(), Gdk.CursorType.SB_LEFT_ARROW);
            }
            else if (Math.fabs(x - peakIndexToPixel(this.endingSample)) <= 8) {
                c = new Cursor.for_display(Gdk.Display.get_default(), Gdk.CursorType.SB_RIGHT_ARROW);
            }
            else if (peakIndexToPixel(this.startingSample) < x &&
                x < peakIndexToPixel(this.endingSample)) {
                c = new Cursor.for_display(Gdk.Display.get_default(), Gdk.CursorType.SB_H_DOUBLE_ARROW);
            }

        }

        if (this.get_window().get_cursor() != c)
            this.get_window().set_cursor(c);
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

        if (this.selection) {
            c.rectangle(peakIndexToPixel(startingSample), 0, peakIndexToPixel(endingSample) - peakIndexToPixel(startingSample), this.get_allocated_height());
            c.set_source_rgb(1.0, 1.0, 1.0);
            c.set_operator(Cairo.Operator.DIFFERENCE);
            c.fill();
        }

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

    private int pixelToPeakIndex(double px) {
        return (int)Math.llrint(px * Math.pow(2, zoom));
    }

    private int peakIndexToPixel(double ind) {
        return (int)Math.llrint(ind / Math.pow(2, zoom));
    }

}
