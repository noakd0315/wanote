# R8 rules for the release build.
#
# This file exists because the release APK crashed on launch, on a real
# device, with:
#
#   Unable to get provider androidx.startup.InitializationProvider:
#     Failed to create an instance of androidx.work.impl.WorkDatabase
#     at androidx.work.WorkManagerInitializer
#
# Nothing in this app uses WorkManager or Room directly. The chain is
#
#   google_mobile_ads -> androidx.work:work-runtime:2.7.0
#                     -> androidx.room:room-runtime:2.2.5
#
# so wiring up ads is what introduced it. WorkManager is initialised by
# androidx.startup at process start, which is why the app died before a
# single frame -- there was no way to catch or recover from it in Dart.

# Room finds its generated database subclass by name and instantiates it
# reflectively. R8 cannot see that call, so it strips the no-argument
# constructor as unused -- the class survives, the constructor does not,
# and Room reports it as "Failed to create an instance of".
#
# Room 2.2.5 is old enough that its bundled rules do not cover this under
# current R8. Upgrading is not ours to do: the version is pinned by a
# transitive dependency of the ads SDK.
-keep class * extends androidx.room.RoomDatabase { <init>(); }

# Kept deliberately narrow. Blanket rules over androidx.** would hide the
# next failure of this kind instead of surfacing it, and would undo the
# size reduction that is the point of shrinking in the first place.
