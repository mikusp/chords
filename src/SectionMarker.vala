public class SectionMarker : Marker, Renderable {
    public SectionMarker(int64 position) {
        this.position = position;
    }

    public override void render(Cairo.Context c, double zoom) {
        if (!this.isVisible(c, zoom))
            return;

        var rec = get_clip_rectangle(c);
        var pos = UnitsConverter.songTimeToPixel(this.position, zoom);

        c.rectangle(pos - 8,
            rec.height * 0.2,
            16,
            rec.height * 0.6);
        c.set_source_rgb(0.56, 0.93, 0.56);
        c.fill();

        c.move_to(pos - 4, rec.height * 0.8);
        c.line_to(pos + 4, rec.height * 0.8);
        c.line_to(pos, rec.height);
        c.close_path();
        c.set_source_rgb(0.0, 0.0, 0.0);
        c.fill();
    }
}
