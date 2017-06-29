# README #

This is a fork of the Video motion estimation toolbox created by Mark Dow at University of Oregon. The original site where the code was hosted (http://lcni.uoregon.edu/~dow/Geek_software/Video_motion/Video_motion_estimation.html#video_total_motion_estimation) it is not working anymore. This toolbox has been previously used in one publication (doi: 10.1016/j.jneumeth.2014.06.002).

### Summary ###

* Quick description.
* Main functions. 
* Workflow.
* Whom do I talk to?.

### Quick description ###

The toolbox works on video file in AVI format. It takes the first frame
as the reference frame, and for every subsequent frame, it computes the 
number of pixels that are different from the reference frame. It outputs
a 1-D array with number of different pixels, the timestamps for each
pixel difference, and a scaling factor to standardize the number of
pixels across different movies.

It also gives the option to select a crop box, that is, a square portion 
of the video to analyze separately, saving time and memory usage.

### Main functions ###

* get_video_frame
* video_total_motion

### Workflow ###

* With cropbox:
    1. Look at the first frame by running:
            im = get_video_frame('NVT-1.avi', 1, true, false );
    2. Select the crop box using the data cursor tool from the matlab figure.
        * select multiple points by using "Alt+click".
    3. The crop box is a 4-element vector with the following elements:
        \[ XbottomLeft YtopLeft XtopRight YbottomRight \]
    4. Now run the motion analysis algorithm:
            [motion,t,dsScale]=video_total_motion_v2('NVT-1.avi',[6 236 314 471],true,true,0);

It will take some time to process, depending on the number of frames, and the size of the crop box.
