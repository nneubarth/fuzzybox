
def initVidPipeline(vidpath): 
	'''
	vidpath: string of video path name
	returns: video pipeline
	'''
	import subprocess as sp
	#name of ffmpeg binary
	FFMPEG_BIN = "ffmpeg" 
	command = [ FFMPEG_BIN,
			'-i', vidpath,
			'-f', 'image2pipe',
			'-pix_fmt', 'rgb24',
			'-vcodec', 'rawvideo', '-']
	return sp.Popen(command, stdout = sp.PIPE, bufsize=10**8)

def skipfirst20(pipe,framerate,xdim,ydim):
	'''
	pipe: video pipeline
	framerate: frame rate of avi video (fps)
	xdim: int indicating x dimensions of video
	ydim: int indicating y dimensions of video
	'''

	for i in range(0,(framerate*20-1)):
		temp = readFrame(pipe,xdim,ydim)
	print 'First 20 seconds of video skipped.'
	return

def readFrame(pipe,xdim,ydim):
	'''
	pipe: video pipeline
	xdim: int indicating x dimensions of video
	ydim: int indicating y dimensions of video
	returns: 2D image of frame as a numpy array
	'''
	import numpy as np
	raw_image = pipe.stdout.read(xdim*ydim*3)
	image =  np.fromstring(raw_image, dtype='uint8')
	if not image.size:
		print 'No more frames in video.'
		return
	image = image.reshape((xdim,ydim,3))
	#change to 2D
	image = image[:,:,1]
	pipe.stdout.flush()
	return image