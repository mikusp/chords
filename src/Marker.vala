public abstract class Marker : Object, Renderable {
    protected int64 position {get; set;}

    public abstract void render(Cairo.Context c, double zoom);
    protected bool isVisible(Cairo.Context c, double zoom) {
        var rect = get_clip_rectangle(c);

        var pixel = UnitsConverter.songTimeToPixel(this.position, zoom);
        if (pixel >= rect.x - 20 && pixel <= rect.x + rect.width + 20)
            return true;

        return false;
    }
}
