public Gdk.Rectangle get_clip_rectangle(Cairo.Context c) {
    Gdk.Rectangle rect;
    Gdk.cairo_get_clip_rectangle(c, out rect);
    return rect;
}
