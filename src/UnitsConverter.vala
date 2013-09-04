public class UnitsConverter {
    public const int samplesPerPixel = 80;

    public static static int pixelToPeakIndex(double px, double zoom) {
        return (int)Math.llrint(px * Math.exp2(zoom));
    }

    public static int peakIndexToPixel(double ind, double zoom) {
        return (int)Math.llrint(ind / Math.exp2(zoom));
    }

    public static int songTimeToPixel(int64 pos, double zoom) {
        // why *2 works? TODO
        return peakIndexToPixel(pos * 44.1 / samplesPerPixel * 2, zoom);
    }

    public static int pixelToSongTime(double px, double zoom) {
        return pixelToPeakIndex(px * (samplesPerPixel / (44.1 * 2)), zoom);
    }

    public static int peakIndexToSongTime(int ind, double zoom) {
        return pixelToSongTime(peakIndexToPixel(ind, zoom), zoom);
    }
}
