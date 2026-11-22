import AudioToolbox

enum SoundEffects {
    static func pageTurn() { AudioServicesPlaySystemSound(1104) }
    static func addBook() { AudioServicesPlaySystemSound(1025) }
    static func softTap() { AudioServicesPlaySystemSound(1105) }
}
