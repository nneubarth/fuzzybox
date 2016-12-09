
from scipy.optimize import leastsq
import subprocess as sp
import numpy as np
import matplotlib.pyplot as plt
import pandas as pd


def initVidPipeline(vidpath): 
	'''
	vidpath: string of video path name
	returns: video pipeline
	'''

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

def sigmoid(p,x):
    '''
    params: p, list of values for the sigmoid function
    L, L + y0 is y-value of top asymptote
    x0, x-value of curve's midpoint
    k, steepness of curve
    y0, y-value of the bottom asymptote
    x, numpy array of x values from the data
    returns: y values of the fit for the data
    '''
    #L, L + y0 is y-value of top asymptote
    #x0, x-value of curve's midpoint
    #k, steepness of curve
    #y0, y-value of the bottom asymptote
    x0,y0,L,k=p
    y = L / (1 + np.exp(-k*(x-x0))) + y0
    return y

def residuals(p, x, y):  
    ''' 
    params: p, list of values for sigmoid function
    x and y are numpy arrays of x and y values respectively
    returns: residuals for use with leastsq function
    '''
    return y - sigmoid(p,x) 

def sigmoidFit(x,y):
    '''
    params: x and y are numpy arrays of x and y values respectively
    returns: the parameters p for use with the sigmoid function as a numpy array
    '''
    start_sigmoid=(np.median(x),min(y),max(y),1.0)
    solution= leastsq(residuals,start_sigmoid,args=(x,y)) 
    print(solution)
    return solution[0]

def convVF_DF(df):
	'''
 	params: df, pandas data frame obtained from von Frey csv file
 	returns: new pandas dataframe with von Frey filament numbers converted to grams and coverted from
 	heading to column, animal IDs and test date removed, withdrawal thresholds in column 'WD' and converted
 	to fraction out of 10.
 	'''
 	forcesdict = {'1.65':.008,'2.36':.02,'2.83':.07,'3.2':.16,'3.61':.4,'3.84':.6,'4.08':1,'4.17':1.4,'4.31':2,'4.56':4}
 	for f in df.columns[3:]:
    	force = forcesdict[f]
    	tempdf = pd.concat([df['Genotype'],df[f]],axis=1)
    	tempdf['Force'] = force
    
    	tempdf.rename(columns={f:'WD'}, inplace=True)
    	tempdf['WD'] = tempdf['WD'].apply(lambda x: x/10.0)
    	try:
        	newdf = pd.concat([newdf,tempdf])
    	except NameError:
        	newdf = tempdf
    return newdf

def separateByGenotype(df,genotype):
	'''
	params: df is a pandas dataframe with von frey data that has been passed through convVF_DF,
	type is a string with either 'TrkB' or 'Ret' to indicate whether the experimental group is 
	Ret conditional or TrkB conditional
	returns: 4 dataframes separated by genotype, extracts only those of the genotype indicated from the original
	dataframe. In order the dataframes are: a wild-type control group, a cre and/or null control group,
	a mutant group, and an all genotypes dataframe. 
	'''
	if genotype == 'TrkB':
		wtc = df[df['Genotype'] == 'TrkBflox/+ or flox']
		crec = df[df['Genotype'] == 'AdvCre/+; TrkBflox/+']
		mt = df[df['Genotype'] == 'AdvCre/+; TrkBflox/flox']
	elif genotype == 'Ret':
		wtc = df[df['Genotype'] == 'Retflox/+']
		crec = df[df['Genotype'] == 'RetCFP/flox or CFP/+']
		mt = df[df['Genotype'] == 'AdvCre/+; RetCFP/flox']
	allgenotypes = pd.concat([wtc,crec,mt])
	return wtc,crec,mt,allgenotypes

def makeAverageDF(df):
	'''
	params: pandas dataframe that has been passed through separateByGenotype
	returns: dataframe with average withdrawal threshold at each force for given genotype
	'''
	genotype = df['Genotype'].take([0]).tolist()[0]
	df_average = df.groupby('Force').mean()
	df_average['Genotype'] = genotype
	df_average.reset_index(level=0,inplace=True)
	return df_average

def calcBootstrap(x,y):
	'''
	params: x and y data points as numpy arrays
	returns: bootstrapped mean sigmoid fit and standard deviation of sigmoid fit as a numpy array
	'''
    x_sig = np.linspace(min(x),max(x),num=100)
    for i in range(1000):
        samp_indices = np.random.choice(range(0,len(x)),size=(1,len(x)),replace=True, p=None)
        sampx = x[samp_indices].flatten()
        sampy = y[samp_indices].flatten()
        try:
            ps = np.vstack((ps, sigmoidFit(sampx,sampy)[0].flatten()))
            all_sigs = np.vstack((all_sigs, sigmoid(sigmoidFit(sampx,sampy)[0],x_sig).flatten()))
        except NameError:
            ps = sigmoidFit(sampx,sampy)[0]
            all_sigs = sigmoid(sigmoidFit(sampx,sampy)[0],x_sig).flatten()
                
    return all_sigs.mean(axis=0), all_sigs.std(axis=0)
