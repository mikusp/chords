using Cairo;
using Gdk;

public class WaveformWidget : Gtk.DrawingArea {
    public float[,] audioData {
        set {
            this.wf.setAudioData(value);
            this.setSizeRequest();
        }
    }
    private Waveform wf {get; set; default = new Waveform();}
    public int64 position {get; set; default = 0;}
    private int positionDrawn {get; set;}
    public double zoom {get; set; default = 0;}
    private State selectionState {get; set; default = State.NONE;}
    private bool selection {get; set; default = false;}
    private double clickPosition {get; set; default = 0.0;}
    private double lastPointerPos {get; set;}
    private int startingSample {get; set;}
    private int endingSample {get; set;}
    public bool scroll {get; set; default = true;}

    public signal void selectionEndReached(int64 startPosition);

    private enum State {
        NONE,
        SELECT,
        MOVE,
        LEFT_EXPAND,
        RIGHT_EXPAND
    }

    public WaveformWidget() {
        this.notify["zoom"].connect(this.setSizeRequest);
        this.notify["position"].connect(() => {
            // exact coordinates are just guesses
            this.queue_draw_area(this.positionDrawn - 5,
                0,
                10,
                this.get_allocated_height());
            this.queue_draw_area(UnitsConverter.songTimeToPixel(this.position, this.zoom) - 5,
                0,
                10,
                this.get_allocated_height());
            if (this.position >= UnitsConverter.peakIndexToSongTime(this.endingSample, this.zoom) && this.selection) {
                this.selectionEndReached(UnitsConverter.peakIndexToSongTime(this.startingSample, this.zoom));
            }
        });
        this.add_events(EventMask.BUTTON_PRESS_MASK | EventMask.BUTTON_RELEASE_MASK |
            EventMask.BUTTON_MOTION_MASK | EventMask.EXPOSURE_MASK |
            EventMask.POINTER_MOTION_HINT_MASK |
            EventMask.POINTER_MOTION_MASK);
        this.button_press_event.connect(this.buttonPressHandler);
        this.button_release_event.connect(this.buttonReleaseHandler);
        this.motion_notify_event.connect(this.motionNotifyHandler);
    }

    private bool buttonPressHandler(Gdk.EventButton e) {
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

        this.clickPosition = e.x;
        return false;
    }

    private bool buttonReleaseHandler(Gdk.EventButton e) {
        if (Math.fabs(e.x - this.clickPosition) <= 2) {
            this.invalidateBounds(this.startingSample, this.endingSample - this.startingSample);
            this.selection = false;
        }
        this.selectionState = State.NONE;

        return false;
    }

    private bool motionNotifyHandler(Gdk.EventMotion e) {
        setDirectionalCursor(e.x);

        var distance = Math.llrint(e.x - this.lastPointerPos);
        var diff = UnitsConverter.pixelToPeakIndex(distance, this.zoom);

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
            if (Math.fabs(e.x - this.clickPosition) >= 5) {
                this.selection = true;

                if (e.x > this.clickPosition) {
                    this.startingSample = UnitsConverter.pixelToPeakIndex(this.clickPosition, this.zoom);
                    this.endingSample = UnitsConverter.pixelToPeakIndex(e.x, this.zoom);
                    this.selectionState = State.RIGHT_EXPAND;
                }
                else {
                    this.startingSample = UnitsConverter.pixelToPeakIndex(e.x, this.zoom);
                    this.endingSample = UnitsConverter.pixelToPeakIndex(this.clickPosition, this.zoom);
                    this.selectionState = State.LEFT_EXPAND;
                }

                this.invalidateBounds(this.startingSample, this.endingSample - this.startingSample);
            }
            break;
        }
        }

        // TODO ensure that startingSample < endingSample
        // particularly while expanding

        this.lastPointerPos = e.x;

        return false;
    }

    private void invalidateBounds(int leftBound, double width) {
        this.queue_draw_area(UnitsConverter.peakIndexToPixel(leftBound, this.zoom),
            0,
            UnitsConverter.peakIndexToPixel(width, this.zoom),
            this.get_allocated_height());
    }

    private void setDirectionalCursor(double x) {
        Cursor c = null;

        if (this.selection || this.selectionState != State.NONE) {
            if (Math.fabs(x - UnitsConverter.peakIndexToPixel(this.startingSample, this.zoom)) <= 8 ||
                this.selectionState == State.LEFT_EXPAND) {
                c = new Cursor.for_display(Gdk.Display.get_default(), Gdk.CursorType.SB_LEFT_ARROW);
            }
            else if (Math.fabs(x - UnitsConverter.peakIndexToPixel(this.endingSample, this.zoom)) <= 8 ||
                this.selectionState == State.RIGHT_EXPAND) {
                c = new Cursor.for_display(Gdk.Display.get_default(), Gdk.CursorType.SB_RIGHT_ARROW);
            }
            else if ((UnitsConverter.peakIndexToPixel(this.startingSample, this.zoom) < x &&
                x < UnitsConverter.peakIndexToPixel(this.endingSample, this.zoom)) ||
                this.selectionState == State.MOVE) {
                c = new Cursor.for_display(Gdk.Display.get_default(), Gdk.CursorType.SB_H_DOUBLE_ARROW);
            }

        }

        if (this.get_window().get_cursor() != c)
            this.get_window().set_cursor(c);
    }

    public override bool draw(Cairo.Context c) {
        c.rectangle(0, 30, this.get_allocated_width(), this.get_allocated_height());
        c.clip();
        c.translate(0, 30);
        var rec = get_clip_rectangle(c);

        wf.render(c, this.zoom);

        drawSongPosition(c, rec);

        var sw = this.get_parent().get_parent() as Gtk.ScrolledWindow;
        var scroll = sw.get_hscrollbar() as Gtk.Range;
        var scrollpos = Math.llrint(scroll.get_value());
        if (this.scroll && this.positionDrawn - scrollpos >= 100)
            scroll.set_value(this.positionDrawn - 100);

        if (this.selection) {
            c.rectangle(UnitsConverter.peakIndexToPixel(startingSample, this.zoom), 0, UnitsConverter.peakIndexToPixel(endingSample, this.zoom) - UnitsConverter.peakIndexToPixel(startingSample, this.zoom), this.get_allocated_height());
            c.set_source_rgb(1.0, 1.0, 1.0);
            c.set_operator(Cairo.Operator.DIFFERENCE);
            c.fill();
        }

        return false;
    }

    private void drawSongPosition(Cairo.Context c, Gdk.Rectangle rec) {
        c.set_line_width(1.0);
        c.set_source_rgb(0.0, 0.0, 0.0);
        c.move_to(UnitsConverter.songTimeToPixel(position, this.zoom) + 0.5, 0);
        c.line_to(UnitsConverter.songTimeToPixel(position, this.zoom) + 0.5, rec.height);
        c.stroke();
        this.positionDrawn = UnitsConverter.songTimeToPixel(this.position, this.zoom);
    }

    private void setSizeRequest() {
        var newWidth = wf.get_width_request(this.zoom);
        this.set_size_request(newWidth, -1);
    }

    public void scrollTo(int64 songPosition) {
        var window = this.get_parent().get_parent() as Gtk.ScrolledWindow;
        var scrollbar = window.get_hscrollbar() as Gtk.Range;

        this.position = songPosition;

        if (this.scroll) {
            var val = UnitsConverter.songTimeToPixel(songPosition, this.zoom);
            scrollbar.set_value(val - 100);
        }
    }

}
