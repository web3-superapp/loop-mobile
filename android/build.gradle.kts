allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// Host-level compatibility override: compile every Android library subproject on API 36.
// privy_flutter 0.10.1 hard-codes compileSdk 34, but its resolved AndroidX
// Credentials 1.5.0 AARs declare minCompileSdk 35.
subprojects {
    afterEvaluate {
        if (plugins.hasPlugin("com.android.library")) {
            extensions.configure<com.android.build.api.dsl.LibraryExtension> {
                compileSdk = 36
            }
        }
    }
}

// Host-level compatibility override (decision 0125): resolve Privy's Android
// core to 0.15.0. privy_flutter 0.10.1 pins io.privy:privy-core:0.12.1, whose
// io.privy.sdk.webview.WebViewState.awaitReady() is `while (!isReady) yield()`
// on Dispatchers.IO, launched from the RealWebViewHandler constructor. Until
// the hidden wallet WebView reports ready — and nothing loads it while the
// reader is only browsing — every DefaultDispatcher worker spins: ~140% CPU
// with the app idle in front, and system ANR dialogs. privy-core 0.14.0
// replaced the loop with a StateFlow wait; 0.15.0 is the version
// privy_flutter 0.10.2 itself ships (its Kotlin bridge is unchanged apart from
// error-code names), with the same third-party dependencies as 0.12.1.
// Override with -Ploop.privyCoreVersion=<version>, or `plugin` to take
// whatever privy_flutter declares. Delete once privy_flutter >= 0.10.2.
val loopPrivyCoreVersion: String =
    (findProperty("loop.privyCoreVersion") as String?) ?: "0.15.0"

subprojects {
    configurations.configureEach {
        resolutionStrategy.eachDependency {
            if (loopPrivyCoreVersion != "plugin" &&
                requested.group == "io.privy" &&
                requested.name == "privy-core"
            ) {
                useVersion(loopPrivyCoreVersion)
                because("privy-core 0.12.1 busy-waits on Dispatchers.IO (decision 0125)")
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
