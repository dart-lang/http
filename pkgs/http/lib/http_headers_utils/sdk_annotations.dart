/// Annotation class marking the version where SDK API was added.
///
/// A `Since` annotation can be applied to a library declaration,
/// any public declaration in a library, or in a class, or to
/// an optional parameter.
///
/// It signifies that the export, member or parameter was *added* in
/// that version.
///
/// When applied to a library declaration, it also a applies to
/// all members declared or exported by that library.
/// If applied to a class, it also applies to all members and constructors
/// of that class.
/// If applied to a class method, or parameter of such,
/// any method implementing that interface method is also annotated.
/// If multiple `Since` annotations apply to the same declaration or
/// parameter, the latest version takes precedence.
///
/// Any use of a marked API may trigger a warning if the using code
/// does not require an SDK version guaranteeing that the API is available,
/// unless the API feature is also provided by something else.
/// It is only a problem if an annotated feature is used, and the annotated
/// API is the *only* thing providing the functionality.
/// For example, using `Future` exported by `dart:core` is not a problem
/// if the same library also imports `dart:async`, and using an optional
/// parameter on an interface is not a problem if the same type also
/// implements another interface providing the same parameter.
///
/// The version must be a semantic version (like `1.4.2` or `0.9.4-rec.4`),
/// or the first two numbers of a semantic version (like `1.0` or `2.2`),
/// representing a stable release, and equivalent to the semantic version
/// you get by appending a `.0`.
@Since('2.2')
class Since {
  final String version;
  const Since(this.version);
}
