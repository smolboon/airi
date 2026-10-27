public enum BeatSyncScaffold {
    /// Names a motion style from a tempo. The microphone stays off.
    public static func style(bpm: Int) -> String? {
        guard (1 ... 300).contains(bpm) else {
            return nil
        }
        if bpm < 120 {
            return "swing-lr"
        }
        if bpm < 180 {
            return "balanced-v"
        }
        return "punchy-v"
    }
}
