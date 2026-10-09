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
// privy_flutter 0.11.0 hard-codes compileSdk 34, but its resolved AndroidX
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

// History (decisions 0125, 0134): privy_flutter 0.10.1 pinned
// io.privy:privy-core:0.12.1, whose WebViewState.awaitReady() busy-waited
// (`while (!isReady) yield()` on Dispatchers.IO) until the hidden wallet
// WebView reported ready: ~140% idle CPU and ANR dialogs. This file used to
// force privy-core to 0.15.0 through a resolutionStrategy override
// (-Ploop.privyCoreVersion). privy_flutter 0.11.0 declares privy-core 0.15.0
// itself, so the override was removed; do not reintroduce one unless a future
// privy_flutter pins a privy-core older than 0.14.0.

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
