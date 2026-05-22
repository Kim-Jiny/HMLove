allprojects {
    repositories {
        google()
        mavenCentral()
    }

    // home_widget 0.9.0 의 'androidx.glance:glance-appwidget:1.+' 가 자동으로 끌어오는
    // 1.3.0-alpha01 은 compileSdk 37 / AGP 9.1+ 을 강제하므로,
    // 안정 버전 1.1.1 로 핀해 현재 AGP 8.11 / compileSdk 36 빌드를 깨지지 않게 한다.
    // (Flutter SDK + 플러그인들이 AGP 9 지원되면 이 핀 제거)
    configurations.all {
        resolutionStrategy.eachDependency {
            if (requested.group == "androidx.glance" &&
                requested.name == "glance-appwidget") {
                useVersion("1.1.1")
                because("home_widget 0.9.0 의 1.+ 가 alpha 끌어오는 문제 회피")
            }
        }
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
