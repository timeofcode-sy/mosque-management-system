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
subprojects {
    project.evaluationDependsOn(":app")
}

// One androidx.annotation for every module. tink-android (flutter_secure_storage 11) asks for 1.8.2
// while the Flutter embedding brings 1.9.1; a plugin resolving on its own picks the older one, which
// Google Maven no longer serves from every network. 1.9.1 is the newer, compatible release.
subprojects {
    configurations.configureEach {
        resolutionStrategy.eachDependency {
            if (requested.group == "androidx.annotation" && requested.name.startsWith("annotation") &&
                requested.version == "1.8.2"
            ) {
                useVersion("1.9.1")
                because("one annotation version for the whole app; 1.8.2 is not reachable everywhere")
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
