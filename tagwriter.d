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

module tagwriter;

import std.exception;
import std.string : format;

import swffile;
import tagtypes;

class TagWriter
{
	ubyte[] buf;
	size_t pos;

	ubyte bitBuf = 0;
	uint bitPos = 8;

	this()
	{
		this.buf = new ubyte[1024];
	}

	void writeU8(ubyte v)
	{
		if (pos == buf.length)
			buf.length *= 2;
		buf[pos++] = v;
	}

	void writeU16(ushort v)
	{
		writeU8(v&0xFF);
		writeU8(cast(ubyte)(v>>8));
	}

	void writeS24(int v)
	{
		writeU8(v&0xFF);
		writeU8(cast(ubyte)(v>>8));
		writeU8(cast(ubyte)(v>>16));
	}

	void writeU32(uint v)
	{
		writeExact(&v, 4);
	}

	void writeS32(int v)
	{
		writeExact(&v, 4);
	}

	void writeExact(const(void)* ptr, size_t len)
	{
		while (pos+len > buf.length)
			buf.length *= 2;
		buf[pos..pos+len] = (cast(ubyte*)ptr)[0..len];
		pos += len;
	}

	void writeFloat(float v)
	{
		static assert(float.sizeof == 4);
		writeExact(&v, 4);
	}

	void writeDouble(double v)
	{
		static assert(double.sizeof == 8);
		writeExact(&v, 8);
	}

	void writeString(string v)
	{
		writeU32(v.length); // U30?
		writeExact(v.ptr, v.length);
	}

	void writeStringZ(string v)
	{
		writeExact(v.ptr, v.length);
		writeU8(0);
	}

	void writeBytes(ubyte[] v)
	{
		writeExact(v.ptr, v.length);
	}

	void writeLengthBytes(ubyte[] v)
	{
		writeU32(v.length); // U30?
		writeExact(v.ptr, v.length);
	}

	void writeFixed8(float v)
	{
		enforce(v <= 127 && v >= -128, "Float too large for fixed 8.8 format!");
		ushort f8 = (cast(short)(v*256)) & 0xffff;
		writeU16(f8);
	}

	void writeBit(bool bit)
	{
		writeBits(bit ? 1 : 0, 1);
	}

	void writeBits(int data, uint size)
	{
		while (size > 0)
		{
			if (size > bitPos)
			{
				bitBuf |= data << (32 - size) >>> (32 - bitPos);

				writeU8(bitBuf);
				size -= bitPos;
				bitBuf = 0;
				bitPos = 8;
			}
			else
			{
				bitBuf |= data << (32 - size) >>> (32 - bitPos);
				bitPos -= size;
				size = 0;

				if (bitPos == 0)
				{
					writeU8(bitBuf);
					bitBuf = 0;
					bitPos = 8;
				}
			}
		}
	}

	void writeUBits(int data, uint size)
	{
		// @TODO: enforce
		writeBits(data, size);
	}

	void writeSBits(int data, uint size)
	{
		// @TODO: enforce
		writeBits(data, size);
	}

	void flushBits()
	{
		if (bitPos != 8)
		{
			writeU8(bitBuf);
			bitBuf = 0;
			bitPos = 8;
		}
	}

	void writeTag(ref SWFFile.Tag tag)
	{
		ushort u = cast(ushort)(tag.type << 6);

		if (tag.length < 0x3F && !tag.forceLongLength)
		{
			u |= tag.length;
			writeU16(u);
		}
		else
		{
			u |= 0x3F;
			writeU16(u);
			writeExact(&tag.length, 4);
		}

		writeExact(tag.data, tag.length);
	}

	void writeRgba(uint rgba)
	{
		writeU8((rgba >> 16) & 0xFF);
		writeU8((rgba >> 8) & 0xFF);
		writeU8((rgba) & 0xFF);
		writeU8((rgba >> 24) & 0xFF);
	}

	void writeEncodedU32(uint v)
	{
		if (v < 128)
		{
			writeU8(cast(ubyte)(v));
		}
		else if (v < 16384)
		{
			writeU8(cast(ubyte)((v & 0x7F) | 0x80));
			writeU8(cast(ubyte)((v >> 7) & 0x7F));
		}
		else if (v < 2097152)
		{
			writeU8(cast(ubyte)((v & 0x7F) | 0x80));
			writeU8(cast(ubyte)((v >> 7) | 0x80));
			writeU8(cast(ubyte)((v >> 14) & 0x7F));
		}
		else if (v < 268435456)
		{
			writeU8(cast(ubyte)((v & 0x7F) | 0x80));
			writeU8(cast(ubyte)(v >> 7 | 0x80));
			writeU8(cast(ubyte)(v >> 14 | 0x80));
			writeU8(cast(ubyte)((v >> 21) & 0x7F));
		}
		else
		{
			writeU8(cast(ubyte)((v & 0x7F) | 0x80));
			writeU8(cast(ubyte)(v >> 7 | 0x80));
			writeU8(cast(ubyte)(v >> 14 | 0x80));
			writeU8(cast(ubyte)(v >> 21 | 0x80));
			writeU8(cast(ubyte)((v >> 28) & 0x0F));
		}
	}

	void writeEncodedS32(int v)
	{
		writeEncodedU32(cast(uint)v);
	}
}
