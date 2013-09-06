public class Waveform : Object, Renderable {
    private Array<float?> audioData = new Array<float?>();

    public Waveform() {}

    public void setAudioData(float[,] data) {
        var i = 0;
        var end = false;
        while (!end) {
            var peak = 0.0f;
            for (var j = i * UnitsConverter.samplesPerPixel; j < (i+1) * UnitsConverter.samplesPerPixel; ++j) {
                if (data.length[1] == j) {
                    end = true;
                    break;
                }

                if (data[0, j] > peak)
                    peak = data[0, j];
            }
            audioData.insert_val(i, peak);
            ++i;
        }
    }

    public void render(Cairo.Context c, double zoom) {
        var rec = get_clip_rectangle(c);

        drawBackground(c, rec);

        c.set_line_width(1.0);
        c.set_source_rgb(0.698, 0.506, 0.376);

        var verticalMiddle = rec.height / 2.0;
        var maxPeakHeight = verticalMiddle;

        if (this.audioData.length != 0)
            for (int i = rec.x; i < rec.x + rec.width; ++i) {
                var maxFromRange = 0.0f;
                for (int j = UnitsConverter.pixelToPeakIndex(i, zoom);
                    j < UnitsConverter.pixelToPeakIndex(i+1, zoom) && j < this.audioData.length;
                    j++) {
                    if (audioData.index(j) > maxFromRange)
                        maxFromRange = audioData.index(j);
                }

                c.move_to(i + 0.5, verticalMiddle - maxFromRange * maxPeakHeight);
                c.line_to(i + 0.5, verticalMiddle + maxFromRange * maxPeakHeight);
                c.stroke();
            }
    }

    private void drawBackground(Cairo.Context c, Gdk.Rectangle rect) {
        c.rectangle(rect.x, rect.y, rect.width, rect.height);
        c.set_source_rgb(1.0, 0.843, 0.737);
        c.fill();
    }

    public int get_width_request(double zoom) {
        return UnitsConverter.peakIndexToPixel(this.audioData.length / 2.0, zoom);
    }
}
