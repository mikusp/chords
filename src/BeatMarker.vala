public class BeatMarker : Marker, Renderable {
    public BeatMarker(int64 position) {
        this.position = position;
    }

    public override void render(Cairo.Context c, double zoom) {
        if (!this.isVisible(c, zoom))
            return;

        var rec = get_clip_rectangle(c);

        c.set_line_width(1.0);
        c.move_to(UnitsConverter.songTimeToPixel(this.position, zoom) + 0.5, rec.height * 0.6);
        c.line_to(UnitsConverter.songTimeToPixel(this.position, zoom) + 0.5, rec.height);
        c.set_source_rgb(0.0, 0.0, 0.0);
        c.stroke();
    }
}
