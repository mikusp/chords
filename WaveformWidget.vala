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
    public int64 position {get; set; default = 0;}
    private int positionDrawn {get; set;}
    public double zoom {get; set; default = 0;}
    private const int samplesPerPixel = 80;
    private GLib.Array<float?> peaks;
    private State selectionState {get; set; default = State.NONE;}
    private bool selection {get; set; default = false;}
    private double clickPosition {get; set; default = 0.0;}
    private double lastPointerPos {get; set;}
    private int startingSample {get; set;}
    private int endingSample {get; set;}
    public bool scroll {get; set; default = true;}

    private enum State {
        NONE,
        SELECT,
        MOVE,
        LEFT_EXPAND,
        RIGHT_EXPAND
    }

    public WaveformWidget() {
        this.peaks = new GLib.Array<float?>();
        this.notify["zoom"].connect(this.setSizeRequest);
        this.notify["position"].connect(() => {
            // exact coordinates are just guesses
            this.queue_draw_area(this.positionDrawn - 5,
                0,
                10,
                this.get_allocated_height());
            this.queue_draw_area(songTimeToPixel(this.position) - 5,
                0,
                10,
                this.get_allocated_height());
        });
        this.add_events(EventMask.BUTTON_PRESS_MASK | EventMask.BUTTON_RELEASE_MASK |
            EventMask.BUTTON_MOTION_MASK | EventMask.EXPOSURE_MASK |
            EventMask.POINTER_MOTION_HINT_MASK |
            EventMask.POINTER_MOTION_MASK);
        this.event.connect(this.eventHandler);
    }

    private bool eventHandler(Gdk.Event e) {
        switch (e.type) {
        case Gdk.EventType.BUTTON_PRESS: {
            var cursor = this.get_window().get_cursor();
            if (cursor != null) {
                if (cursor.cursor_type == Gdk.CursorType.SB_H_DOUBLE_ARROW)
                    this.selectionState = State.MOVE;
                else if (cursor.cursor_type == Gdk.CursorType.SB_LEFT_ARROW)
                    this.selectionState = State.LEFT_EXPAND;
                else if (cursor.cursor_type == Gdk.CursorType.SB_RIGHT_ARROW)
                    this.selectionState = State.RIGHT_EXPAND;
            }
            else
                this.selectionState = State.SELECT;

            this.clickPosition = e.button.x;
            break;
        }
        case Gdk.EventType.BUTTON_RELEASE: {
            if (Math.fabs(e.button.x - this.clickPosition) <= 2) {
                this.invalidateBounds(this.startingSample, this.endingSample - this.startingSample);
                this.selection = false;
            }
            this.selectionState = State.NONE;
            break;
        }
        case Gdk.EventType.MOTION_NOTIFY: {
            setDirectionalCursor(e.motion.x);

            var distance = Math.llrint(e.motion.x - this.lastPointerPos);
            var diff = pixelToPeakIndex(distance);

            switch (this.selectionState) {
            case State.MOVE: {
                this.startingSample += diff;
                this.endingSample += diff;
                if (diff < 0) { // move left
                    this.invalidateBounds(this.startingSample, Math.fabs(diff));
                    this.invalidateBounds(this.endingSample, Math.fabs(diff));
                }
                else {
                    this.invalidateBounds(this.startingSample - diff, diff);
                    this.invalidateBounds(this.endingSample - diff, diff);
                }
                break;
            }
            case State.LEFT_EXPAND: {
                this.startingSample += diff;
                if (diff < 0)
                    this.invalidateBounds(this.startingSample, Math.fabs(diff));
                else
                    this.invalidateBounds(this.startingSample - diff, diff);
                break;
            }
            case State.RIGHT_EXPAND: {
                this.endingSample += diff;
                if (diff < 0)
                    this.invalidateBounds(this.endingSample, Math.fabs(diff));
                else
                    this.invalidateBounds(this.endingSample - diff, diff);
                break;
            }
            case State.SELECT: {
                if (Math.fabs(e.motion.x - this.clickPosition) >= 5) {
                    this.selection = true;

                    if (e.motion.x > this.clickPosition) {
                        this.startingSample = pixelToPeakIndex(this.clickPosition);
                        this.endingSample = pixelToPeakIndex(e.motion.x);
                        this.selectionState = State.RIGHT_EXPAND;
                    }
                    else {
                        this.startingSample = pixelToPeakIndex(e.motion.x);
                        this.endingSample = pixelToPeakIndex(this.clickPosition);
                        this.selectionState = State.LEFT_EXPAND;
                    }

                    this.invalidateBounds(this.startingSample, this.endingSample - this.startingSample);
                }
                break;
            }
            }

            // TODO ensure that startingSample < endingSample
            // particularly while expanding

            this.lastPointerPos = e.motion.x;
            break;
        }
        default:
            break;
        }

        return false;
    }

    private void invalidateBounds(int leftBound, double width) {
        this.queue_draw_area(peakIndexToPixel(leftBound),
            0,
            peakIndexToPixel(width),
            this.get_allocated_height());
    }

    private void setDirectionalCursor(double x) {
        Cursor c = null;

        if (this.selection || this.selectionState != State.NONE) {
            if (Math.fabs(x - peakIndexToPixel(this.startingSample)) <= 8 ||
                this.selectionState == State.LEFT_EXPAND) {
                c = new Cursor.for_display(Gdk.Display.get_default(), Gdk.CursorType.SB_LEFT_ARROW);
            }
            else if (Math.fabs(x - peakIndexToPixel(this.endingSample)) <= 8 ||
                this.selectionState == State.RIGHT_EXPAND) {
                c = new Cursor.for_display(Gdk.Display.get_default(), Gdk.CursorType.SB_RIGHT_ARROW);
            }
            else if ((peakIndexToPixel(this.startingSample) < x &&
                x < peakIndexToPixel(this.endingSample)) ||
                this.selectionState == State.MOVE) {
                c = new Cursor.for_display(Gdk.Display.get_default(), Gdk.CursorType.SB_H_DOUBLE_ARROW);
            }

        }

        if (this.get_window().get_cursor() != c)
            this.get_window().set_cursor(c);
    }

    public override bool draw(Cairo.Context c) {
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
        var expZoom = Math.exp2(this.zoom);

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
        drawSongPosition(c);

        var sw = this.get_parent().get_parent() as Gtk.ScrolledWindow;
        var scroll = sw.get_hscrollbar() as Gtk.Range;
        var scrollpos = Math.llrint(scroll.get_value());
        if (this.scroll && this.positionDrawn - scrollpos >= 100)
                scroll.set_value(this.positionDrawn - 100);

        if (this.selection) {
            c.rectangle(peakIndexToPixel(startingSample), 0, peakIndexToPixel(endingSample) - peakIndexToPixel(startingSample), this.get_allocated_height());
            c.set_source_rgb(1.0, 1.0, 1.0);
            c.set_operator(Cairo.Operator.DIFFERENCE);
            c.fill();
        }

        return false;
    }

    private void drawSongPosition(Cairo.Context c) {
        c.set_line_width(1.0);
        c.set_source_rgb(0.0, 0.0, 0.0);
        c.move_to(songTimeToPixel(position) + 0.5, 0);
        c.line_to(songTimeToPixel(position) + 0.5, this.get_allocated_height());
        c.stroke();
        this.positionDrawn = songTimeToPixel(this.position);
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
        var newWidth = (int)(this.peaks.length / Math.exp2(this.zoom));
        this.set_size_request(newWidth, -1);
    }

    private int pixelToPeakIndex(double px) {
        return (int)Math.llrint(px * Math.exp2(zoom));
    }

    private int peakIndexToPixel(double ind) {
        return (int)Math.llrint(ind / Math.exp2(zoom));
    }

    private int songTimeToPixel(int64 pos) {
        // why *2 works? TODO
        return peakIndexToPixel(pos * 44.1 / samplesPerPixel * 2);
    }

}
