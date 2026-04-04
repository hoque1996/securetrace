buildscript {
    extra["kotlin_version"] = "2.1.21"
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // 🔁 Change AGP version from 8.4.2 to 8.9.1
        classpath("com.android.tools.build:gradle:8.9.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.1.21")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
    // ❌ Remove this entire 'configurations.all' block - it was forcing old AGP version
    // configurations.all {
    //     resolutionStrategy {
    //         force("com.android.tools.build:gradle:8.4.2")
    //     }
    // }
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

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
