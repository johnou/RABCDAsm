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

module tagreader;

import std.exception;
import std.c.string;

import swffile;

class TagReader
{
	ubyte[] buf;
	size_t pos;

	ubyte bitBuf;
	uint bitPos;

	enum ulong MAX_UINT = (1L << 36) - 1;
	enum long  MAX_INT  = MAX_UINT / 2;
	enum long  MIN_INT  = -MAX_INT - 1;

	this(ubyte[] buf)
	{
		this.buf = buf;
	}

	ubyte readU8()
	{
		enforce(pos < buf.length, "End of tag reached");
		return buf[pos++];
	}

	ushort readU16()
	{
		return readU8() | readU8() << 8;
	}

	int readS24()
	{
		return readU8() | readU8() << 8 | cast(int)(readU8() << 24) >> 8;
	}

	uint readU32()
	{
		uint r;
		readExact(&r, 4);
		return r;
	}

	int readS32()
	{
		int r;
		readExact(&r, 4);
		return r;
	}

	void readExact(void* ptr, size_t len)
	{
		enforce(pos+len <= buf.length, "End of tag reached");
		(cast(ubyte*)ptr)[0..len] = buf[pos..pos+len];
		pos += len;
	}

	float readFloat()
	{
		float f;
		static assert(float.sizeof == 4);
		readExact(&f, 4);
		return f;
	}

	double readDouble()
	{
		double r;
		static assert(double.sizeof == 8);
		readExact(&r, 8);
		return r;
	}

	string readStringZ()
	{
		enforce(pos < buf.length, "End of tag reached");
		char * cstr = cast(char *)&buf[pos];
		uint len = strlen(cstr);
		string s = cast(string) cstr[0..len];
		pos += len + 1;
		return s;
	}

	void readArray(void[] a)
	{
		a[] = buf[pos..pos+a.length];
		pos += a.length;
	}

	/// May read less than len on EOF
	void[] readArray(size_t len)
	{
		auto end = pos+len;
		auto data = buf[pos..end<$?end:$];
		pos = end;
		return data;
	}

	SWFFile.Tag readTag()
	{
		SWFFile.Tag t;
		ushort u = readU16();
		t.type = cast(ushort)(u >> 6);
		uint length = u & 0x3F;
		if (length == 0x3F)
		{
			readExact(&length, 4);
			if (length < 0x3F)
				t.forceLongLength = true;
		}
		t.length = length;
	    t.data = cast(ubyte[])readArray(length);
		assert(t.length == t.data.length);
		return t;
	}

	uint readRgba()
	{
		uint color = readU8() << 16; // red
		color |= readU8() << 8; // green
		color |= readU8(); // blue
		color |= readU8() << 24; // alpha

		return color; // 0xAARRGGBB
	}

	bool readBit()
	{
		return readUBits(1) != 0;
	}

	uint readUBits(uint numBits)
	{
		enforce(numBits < 33, "Too many bits!");

		void readNext() { bitBuf = readU8(); bitPos = 8; }

		if (numBits == 0)
			return 0;

		uint bitsLeft = numBits;
		uint result = 0;

		if (bitPos == 0)
			readNext();

		while (true)
		{
			int shift = bitsLeft - bitPos;

			if (shift > 0)
			{
				result |= bitBuf << shift;
				bitsLeft -= bitPos;

				readNext();
			}
			else
			{
				result |= bitBuf >> -shift;
				bitPos -= bitsLeft;
				bitBuf &= 0xff >> (8 - bitPos);

				return result;
			}
		}

		return result;
	}

	int readSBits(uint numBits)
	{
		enforce(numBits < 33, "Too many bits!");

		int num = readUBits(numBits);
		int shift = 32 - numBits;
		num = (num << shift) >> shift;

		return num;
	}

	void syncBits()
	{
		bitPos = 0;
	}
}
