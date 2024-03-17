// CS 218 - Provided C++ program
//	This programs calls assembly language routines.

//  Must ensure g++ compiler is installed:
//	sudo apt-get install g++

// ***************************************************************************

#include <cstdlib>
#include <iostream>
#include <fstream>
#include <cstdlib>
#include <string>
#include <iomanip>
#include <cmath>

using namespace std;

// ***************************************************************
//  Prototypes for external functions.
//	The "C" specifies to use the standard C/C++ style
//	calling convention.

enum imageOptions {GRAYSCALE=0, BRIGHTEN=1, DARKEN=2};

extern "C" bool getArguments(int, char* [], imageOptions *, FILE **, FILE **);
extern "C" bool processHeaders(FILE*, FILE*, unsigned int *, unsigned int *,
					unsigned int *);
extern "C" bool getRow(FILE *, unsigned int, unsigned char []);
extern "C" bool imageCvtToBW(unsigned int, unsigned char []);
extern "C" bool imageBrighten(unsigned int, unsigned char []);
extern "C" bool imageDarken(unsigned int, unsigned char []);
extern "C" bool writeRow(FILE *, int, unsigned char []);

// ***************************************************************
//  Basic C++ program (does not use any objects).

int main (int argc, char* argv[])
{
//  Declare variables and simple display header

	FILE			*originalImage=0, *newImage=0;
	const unsigned int	MAX_WIDTH = 10000;
	unsigned int		fileSize=0, picHeight=0, picWidth=0;
	double			aspectRatio=0.0;
	unsigned char		*rowBuffer=NULL;
	imageOptions		imgOption;
	string			bars;
	bars.append(50,'-');

// Get image option, input and output file descriptors.
//	Includes verifying the file names by opening the files. 
//	If successful, returns file descriptors for both in and out files.

	if (getArguments(argc, argv, &imgOption, &originalImage, &newImage)) {

		// Read and verify picture header header information.
		//	Also writes header information to output file.
		if (!processHeaders(originalImage, newImage, &fileSize,
					&picWidth, &picHeight))
			return	EXIT_SUCCESS;

		if (picWidth > MAX_WIDTH) {
			cout << "Error, source image file has " <<
				"unsupported width." << endl <<
				"Program terminated." << endl;
			return	EXIT_SUCCESS;
		}

		aspectRatio = static_cast<double>(picHeight) /
					static_cast<double>(picWidth);

		if (aspectRatio < 0.25|| aspectRatio > 4.0) {
			cout << "Error, invalid image aspect ratio" <<
				"Program terminated." << endl;
			return	EXIT_SUCCESS;
		}

		rowBuffer = new unsigned char [picWidth*3];

		// Main procesing loop
		//	read row
		//	image processing (based on option)
		//		convert to grayscale
		//		brighten
		//		darken
		//	write row

		while (getRow(originalImage, picWidth, rowBuffer)) {

			switch (imgOption) {
				case GRAYSCALE:
					imageCvtToBW(picWidth, rowBuffer);
					break;
				case BRIGHTEN:
					imageBrighten(picWidth, rowBuffer);
					break;
				case DARKEN:
					imageDarken(picWidth, rowBuffer);
					break;
				default:
					cout << "Error..." << endl;
			}

			if(!writeRow(newImage, picWidth, rowBuffer)) {
				delete [] rowBuffer;
				fclose(originalImage);
				fclose(newImage);
				return	EXIT_SUCCESS;		
			}
		}
	}

// --------------------------------------------------------------------
//  Note, file are closed automatically by OS.
//  All done...

	return	EXIT_SUCCESS;
}

