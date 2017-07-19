# spm12-level1

This is example code to make/run level1 batch scripts on SPM12. The 'wrapper' script is what you should call in Matlab; the wrapper will then call the 'run' function. The 'wrapper' script organizes subject info and the locations for their necessary files. The 'run' function loads the subject files and creates/runs the batch scripts. This code generates a "subInfo" struct that will contain each subject's ID, folder name, image file locations, motion parameter locations, task output location, task info (group, condition, etc), etc. The "subInfo" struct can be used to run level2 analyses. 

<b>IMPORTANT:</b> This is only a *framework* to make a working level1 script for your task. You will have to make major edits on sections that say "edit this to match your task" in *both* the 'wrapper' script and 'run' function.

<b>Current issues:</b>
* Bother with finding subject IDs or just use subject folder names?
* When to parfor or for
* Still need to properly test on Hoffman2 once the /u/project/sanscn/data permissions issues are sorted out
