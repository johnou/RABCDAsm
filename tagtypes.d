/*
 *  Copyright 2013 Tony Tyson <teesquared@twistedwords.net>
 *  Copyright 2010, 2011 Vladimir Panteleev <vladimir@thecybershadow.net>
 *  This file is part of RABCDAsm.
 *
 *  RABCDAsm is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  RABCDAsm is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with RABCDAsm.  If not, see <http://www.gnu.org/licenses/>.
 */

module tagtypes;

import std.string : format;

import swffile;
import tagutils;

struct Matrix
{
	bool hasScale = false;
	int scaleX = 0;
	int scaleY = 0;
	bool hasRotate = false;
	int rotateSkew0 = 0;
	int rotateSkew1 = 0;
	int translateX = 0;
	int translateY = 0;

	uint getNumScaleBits()
	{
		return minBits(maxNum(scaleX, scaleY, 0, 0), true);
	}

	uint getNumRotateBits()
	{
		return minBits(maxNum(rotateSkew0, rotateSkew1, 0, 0), true);
	}

	uint getNumTranslateBits()
	{
		return minBits(maxNum(translateX, translateY, 0, 0), true);
	}

	string toString()
	{
		string r = "";

		r ~= hasScale ? format("s %d,%d b%d ", scaleX, scaleY, getNumScaleBits()) : "";
		r ~= hasRotate ? format("r %d,%d b%d ", rotateSkew0, rotateSkew1, getNumRotateBits()) : "";
		r ~= format("t %d,%d b%d ", translateX, translateY, getNumTranslateBits());

		return r;
	}
}

struct ColorTransform
{
	bool hasMult;

	int redMultTerm;
	int greenMultTerm;
	int blueMultTerm;
	int alphaMultTerm;

	bool hasAdd;

	int redAddTerm;
	int greenAddTerm;
	int blueAddTerm;
	int alphaAddTerm;

	bool hasAlpha;

	uint getNumBits()
	{
		uint maxMult = maxNum(redMultTerm, greenMultTerm, blueMultTerm, alphaMultTerm);
		uint maxAdd  = maxNum(redAddTerm,  greenAddTerm,  blueAddTerm,  alphaAddTerm);
		uint mb = minBits(maxNum(maxMult, maxAdd, 0, 0), true);
		return mb ? mb : 1;
	}

	string toString()
	{
		string r = "";

		if (hasMult)
		{
			r ~= format("m %d,%d,%d", redMultTerm, greenMultTerm, blueMultTerm);
			r ~= hasAlpha ? format(",%d ", alphaMultTerm) : " ";
		}

		if (hasAdd)
		{
			r ~= format("m %d,%d,%d", redAddTerm, greenAddTerm, blueAddTerm);
			r ~= hasAlpha ? format(",%d ", alphaAddTerm) : " ";
		}

		r ~= format("b%d ", getNumBits());

		return r;
	}
}

struct ClipActions
{
	uint allEventFlags;
	ClipActionRecord[] clipActionRecords;
}

struct ClipActionRecord
{
	uint eventFlags;
	ubyte keyCode;
	Action[] actions;

	uint getActionsLength()
	{
		uint length = 0;

		foreach (ref a; actions)
			length += a.getLength();

		return length;
	}
}

struct Action
{
	ubyte actionCode;
	ubyte[] data;

	uint getLength()
	{
		return data.length + 1;
	}
}

enum FilterType : ubyte
{
	DropShadow = 0,
	Blur = 1,
	Glow = 2,
	Bevel = 3,
	GradientGlow = 4,
	Convolution = 5,
	ColorMatrix = 6,
	GradientBevel = 7,
	Max
}

struct Filter
{
	FilterType type;
	union
	{
		struct _DropShadowFilter
		{
			uint color;
			int blurX;
			int blurY;
			int angle; // 8.8 fixed
			int distance;
			ushort strength;
			ubyte flags;
		} _DropShadowFilter DropShadowFilter;

		struct _BlurFilter
		{
			int blurX;
			int blurY;
			ubyte passes; // UB[5] with UB[3] reserved
		} _BlurFilter BlurFilter;

		struct _GlowFilter
		{
			uint color;
			int blurX;
			int blurY;
			ushort strength;
			ubyte flags;
		} _GlowFilter GlowFilter;

		struct _BevelFilter
		{
			uint shadowColor;
			uint highlightColor;
			int blurX;
			int blurY;
			int angle; // 8.8 fixed
			int distance;
			ushort strength;
			ubyte flags;
		} _BevelFilter BevelFilter;

		struct _GradientGlowFilter // extends GlowFilter
		{
			//int color;
			int blurX;
			int blurY;
			ushort strength;
			ubyte flags;
			ubyte numColors;
			uint[] gradientColors;
			ubyte[] gradientRatio;
			int angle; // 8.8 fixed
			int distance;
		} _GradientGlowFilter GradientGlowFilter;

		struct _ConvolutionFilter
		{
			ubyte matrixX;
			ubyte matrixY;
			float divisor;
			float bias;
			float[] matrix;
			uint color;
			ubyte flags;
		} _ConvolutionFilter ConvolutionFilter;

		struct _ColorMatrixFilter
		{
			float[20] values;
		} _ColorMatrixFilter ColorMatrixFilter;

		struct _GradientBevelFilter // extends Bevel
		{
			uint shadowColor;
			uint highlightColor;
			int blurX;
			int blurY;
			int angle; // 8.8 fixed
			int distance;
			ushort strength;
			ubyte flags;
			ubyte numColors;
			uint[] gradientColors;
			ubyte[] gradientRatio;
		} _GradientBevelFilter GradientBevelFilter;
	}
}
