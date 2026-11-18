import Foundation

/// Tłumaczenie tekstu. Kluczem jest tekst polski (język bazowy programu);
/// angielskie odpowiedniki są w en.lproj/Localizable.strings w pakiecie .app.
/// Gdy tłumaczenia brak (np. w testach albo przy `swift run`), zostaje tekst polski.
public func L(_ key: String, _ args: CVarArg...) -> String {
    let format = Bundle.main.localizedString(forKey: key, value: key, table: nil)
    return args.isEmpty ? format : String(format: format, arguments: args)
}
