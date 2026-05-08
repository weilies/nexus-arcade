# ------------------------------------------------------------------------------
# Description
# -----------
# Command line interface for the GUT unit testing tool.  Allows you to run tests
# from the command line instead of running a scene.  You can run this script
# (from the root of your project) using the following command:
# 	godot -s addons/gut/gut_cmdln.gd
#
# Options:
#   -gdir=<path>    Directory to search for test scripts (can specify multiple)
#   -gprefix=<str>  Prefix for test files (default: test_)
#   -gsuffix=<str>  Suffix for test files (default: .gd)
#   -gselect=<str>  Only run tests matching name
#   -glog=<0|1|2>   Log level (default: 1)
#   -gcolor         Enable color output
#   -gh             Display help
# ------------------------------------------------------------------------------
extends SceneTree

func _init():
	var max_iter = 20
	var iter = 0

	while Engine.get_main_loop() == null and iter < max_iter:
		await create_timer(.01).timeout
		iter += 1

	if Engine.get_main_loop() == null:
		push_error('Main loop did not start in time.')
		quit(1)
		return

	# Parse command-line arguments
	var dirs: Array[String] = []
	var prefix = 'test_'
	var suffix = '.gd'
	var select_script = ''
	var log_level = 1
	var use_color = false

	for arg in OS.get_cmdline_args():
		if arg.begins_with('-gdir='):
			dirs.append(arg.trim_prefix('-gdir='))
		elif arg.begins_with('-gprefix='):
			prefix = arg.trim_prefix('-gprefix=')
		elif arg.begins_with('-gsuffix='):
			suffix = arg.trim_prefix('-gsuffix=')
		elif arg.begins_with('-gselect='):
			select_script = arg.trim_prefix('-gselect=')
		elif arg.begins_with('-glog='):
			log_level = arg.trim_prefix('-glog=').to_int()
		elif arg == '-gcolor':
			use_color = true
		elif arg == '-gh':
			print("""
GUT Command Line Options:
  -gdir=<path>    Directory to search for test scripts (can specify multiple)
  -gprefix=<str>  Prefix for test files (default: test_)
  -gsuffix=<str>  Suffix for test files (default: .gd)
  -gselect=<str>  Only run tests matching name
  -glog=<0|1|2>   Log level (default: 1)
  -gcolor         Enable color output
  -gh             Display this help
			""")
			quit(0)
			return

	if dirs.is_empty():
		dirs.append('res://tests/')

	var gut = GutMain.new()
	gut.include_subdirectories = false
	gut.log_level = log_level
	gut.color_output = use_color

	if select_script != '':
		gut.select_script(select_script)

	for d in dirs:
		gut.add_directory(d, prefix, suffix)

	get_root().add_child(gut)
	await create_timer(0.2).timeout
	gut.test_scripts()
	await create_timer(0.3).timeout

	var tc = gut.get_test_collector()
	var fail_count = tc.get_fail_count()

	print("\n=== RESULTS ===")
	print("Tests ran: ", tc.get_ran_test_count())
	print("Passed: ", tc.get_pass_count())
	print("Failed: ", fail_count)

	if fail_count > 0:
		quit(1)
	else:
		quit(0)


# ##############################################################################
#(G)odot (U)nit (T)est class
#
# ##############################################################################
# The MIT License (MIT)
# =====================
#
# Copyright (c) 2023 Tom "Butch" Wesley
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
# ##############################################################################
