allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}
subprojects {
    plugins.withId("com.android.library") {
        if (project.name == "image_picker_android") {
            project.dependencies.add("implementation", project(":flutter_plugin_android_lifecycle"))
        }
    }
    afterEvaluate {
        project.extensions.findByName("android")?.let { androidExt ->
            try {
                val setBuildTools = androidExt.javaClass.getMethod("buildToolsVersion", String::class.java)
                setBuildTools.invoke(androidExt, "35.0.0")
            } catch (_: Exception) {}
        }
    }
}


tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
