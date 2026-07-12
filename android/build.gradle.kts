import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

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
    if (project.name == "file_picker") {
        project.plugins.apply("org.jetbrains.kotlin.android")
        project.tasks.withType<KotlinCompile>().configureEach {
            compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }
    // ملاحظة: كان هون إجبار compileSdk=36 على mobile_scanner، لكنه كان
    // Workaround خاص بنسخة 3.5.7 القديمة. بعد الترقية لـ 7.2.0 (اللي
    // بتحدد compileSdk المناسب لحالها تلقائياً)، هالإجبار صار غير لازم
    // وممكن يسبب تعارض إصدارات (ABI/resources) وراء كراش الكاميرا
    // "Attempt to invoke virtual method ... on a null object reference"
}

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
