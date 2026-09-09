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

// file_picker 8.x pins API 34, while its current Android lifecycle dependency
// requires consumers to compile against API 36.
subprojects {
    if (name == "file_picker") {
        afterEvaluate {
            extensions.configure<com.android.build.gradle.LibraryExtension> {
                compileSdk = 36
            }
        }
    }
}

// flutter_webrtc contains Java code that references a Kotlin class in the same
// source set. Package the generated Kotlin output so Javac can resolve it in a
// restricted Windows environment where directory canonicalization is blocked.
subprojects {
    if (name == "flutter_webrtc") {
        plugins.withId("com.android.library") {
            val kotlinClasses =
                layout.buildDirectory.dir(
                    "intermediates/built_in_kotlinc/debug/compileDebugKotlin/classes",
                )
            val kotlinClassesJar =
                tasks.register<org.gradle.jvm.tasks.Jar>("packageDebugKotlinClassesForJavac") {
                    dependsOn("compileDebugKotlin")
                    from(kotlinClasses)
                    archiveFileName.set("kotlin-classes-for-javac.jar")
                    destinationDirectory.set(
                        layout.buildDirectory.dir("intermediates/kotlin_classes_jar/debug"),
                    )
                }
            tasks
                .withType<org.gradle.api.tasks.compile.JavaCompile>()
                .matching { it.name == "compileDebugJavaWithJavac" }
                .configureEach {
                    dependsOn(kotlinClassesJar)
                    doFirst {
                        // A jar is used here because Javac may not resolve a
                        // generated class directory in restricted Windows environments.
                        classpath = project.files(classpath, kotlinClassesJar.flatMap { it.archiveFile })
                    }
                }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
