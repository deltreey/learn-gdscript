extends PanelContainer

const CourseLessonList := preload("res://ui/components/CourseLessonList.gd")
const LessonDetails := preload("./CourseLessonDetails.gd")


var course: Course setget set_course
var _current_lesson: Lesson
var _current_practice: Practice

onready var _title_label := $MarginContainer/Layout/TitleBox/TitleLabel as Label
onready var _lesson_list := $MarginContainer/Layout/HBoxContainer/LessonList as CourseLessonList
onready var _lesson_details := $MarginContainer/Layout/HBoxContainer/LessonDetails as LessonDetails


func _ready() -> void:
	_update_outliner_index()
	
	Events.connect("lesson_started", self, "_on_lesson_started")
	Events.connect("quiz_completed", self, "_on_quiz_completed")
	Events.connect("practice_started", self, "_on_practice_started")
	Events.connect("practice_completed", self, "_on_practice_completed")
	Events.connect("lesson_completed", self, "_on_lesson_completed")
	Events.connect("course_completed", self, "_on_course_completed")
	
	_lesson_list.connect("lesson_selected", self, "_on_lesson_selected")


func set_course(value: Course) -> void:
	course = value
	# Ensure that the user profile and the course progression data exists.
	var user_profile = UserProfiles.get_profile()
	user_profile.get_or_create_course(course.resource_path)
	
	_update_outliner_index()


func _update_outliner_index() -> void:
	_lesson_list.clear()
	_lesson_details.hide()
	_title_label.text = ""
	if not course:
		return
	
	_title_label.text = course.title
	
	var user_profile = UserProfiles.get_profile()
	var lesson_index := 0
	for lesson_data in course.lessons:
		lesson_data = lesson_data as Lesson
		var lesson_progress := (
			user_profile.get_or_create_lesson(course.resource_path, lesson_data.resource_path) as LessonProgress
		)
		
		var completion := _calculate_lesson_completion(lesson_data, lesson_progress)
		_lesson_list.add_item(lesson_index, lesson_data.title, completion)
		lesson_index += 1


func _calculate_lesson_completion(lesson_data: Lesson, lesson_progress: LessonProgress) -> int:
	var completion := 0
	var max_completion := 1 + lesson_data.practices.size() + lesson_data.get_total_quizzes()
	
	if lesson_progress.completed_reading:
		completion += 1
	
	completion += lesson_progress.get_completed_quizzes_count(lesson_data.get_total_quizzes())
	completion += lesson_progress.get_completed_practices_count(lesson_data.practices)
	
	return int(clamp(float(completion) / float(max_completion) * 100, 0, 100))


func _on_lesson_selected(lesson_index: int) -> void:
	if not course or lesson_index < 0 or lesson_index >= course.lessons.size():
		return
	
	var lesson_data := course.lessons[lesson_index] as Lesson
	_lesson_details.lesson = lesson_data
	
	var user_profile = UserProfiles.get_profile()
	var lesson_progress := (
		user_profile.get_or_create_lesson(course.resource_path, lesson_data.resource_path) as LessonProgress
	)
	_lesson_details.lesson_progress = lesson_progress
	_lesson_details.show()


func _on_lesson_started(lesson_data: Lesson) -> void:
	_current_lesson = lesson_data
	_current_practice = null
	
	var user_profile = UserProfiles.get_profile()
	user_profile.set_last_started_lesson(course.resource_path, _current_lesson.resource_path)
	_update_outliner_index()


func _on_quiz_completed(quiz_index: int) -> void:
	if not _current_lesson:
		return
	
	var user_profile = UserProfiles.get_profile()
	user_profile.set_lesson_quiz_completed(course.resource_path, _current_lesson.resource_path, quiz_index, true)
	_update_outliner_index()


func _on_practice_started(practice_data: Practice) -> void:
	if not _current_lesson:
		return
	_current_practice = practice_data
	
	var user_profile = UserProfiles.get_profile()
	user_profile.set_lesson_reading_completed(course.resource_path, _current_lesson.resource_path, true)
	_update_outliner_index()


func _on_practice_completed(practice_data: Practice) -> void:
	if not _current_lesson or not _current_practice:
		return
	
	var user_profile = UserProfiles.get_profile()
	user_profile.set_lesson_practice_completed(course.resource_path, _current_lesson.resource_path, practice_data.resource_path, true)
	_update_outliner_index()
	_current_practice = null


func _on_lesson_completed(_lesson_data: Lesson) -> void:
	_current_lesson = null
	_update_outliner_index()


func _on_course_completed(_course_data: Course) -> void:
	_update_outliner_index()
