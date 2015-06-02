/*

Copyright (c) 2015, Project OSRM, Dennis Luxen, others
All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

Redistributions of source code must retain the above copyright notice, this list
of conditions and the following disclaimer.
Redistributions in binary form must reproduce the above copyright notice, this
list of conditions and the following disclaimer in the documentation and/or
other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

*/

#include "fingerprint.hpp"

#include "osrm_exception.hpp"

#include <boost/uuid/name_generator.hpp>

#include <algorithm>
#include <string>

#define HAS64BITS 0
#define MD5PREPARE "cd247d78c1bc958825f65b04428665fe"
#define MD5RTREE "4fe9a7107685595234471140c0af5b2f"
#define MD5GRAPH "bafa784d6e7af8189873e53215371b7b"
#define MD5OBJECTS "2da166728e3c5cc070f022b82815f98a"

FingerPrint::FingerPrint() : magic_number(1297240911)
{
    md5_prepare[32] = md5_tree[32] = md5_graph[32] = md5_objects[32] = '\0';

    boost::uuids::name_generator gen(named_uuid);
    std::string temp_string;

    std::memcpy(md5_prepare, MD5PREPARE, strlen(MD5PREPARE));
    temp_string += md5_prepare;
    std::memcpy(md5_tree, MD5RTREE, 32);
    temp_string += md5_tree;
    std::memcpy(md5_graph, MD5GRAPH, 32);
    temp_string += md5_graph;
    std::memcpy(md5_objects, MD5OBJECTS, 32);
    temp_string += md5_objects;

    named_uuid = gen(temp_string);
    has_64_bits = HAS64BITS;
}

FingerPrint::~FingerPrint() {}

const boost::uuids::uuid &FingerPrint::GetFingerPrint() const { return named_uuid; }

bool FingerPrint::IsMagicNumberOK() const { return 1297240911 == magic_number; }

bool FingerPrint::TestGraphUtil(const FingerPrint &other) const
{
    if (!other.IsMagicNumberOK())
    {
        throw osrm::exception("hsgr input file misses magic number. Check or reprocess the file");
    }
    return std::equal(md5_graph, md5_graph + 32, other.md5_graph);
}

bool FingerPrint::TestPrepare(const FingerPrint &other) const
{
    if (!other.IsMagicNumberOK())
    {
        throw osrm::exception("osrm input file misses magic number. Check or reprocess the file");
    }
    return std::equal(md5_prepare, md5_prepare + 32, other.md5_prepare);
}

bool FingerPrint::TestRTree(const FingerPrint &other) const
{
    if (!other.IsMagicNumberOK())
    {
        throw osrm::exception("r-tree input file misses magic number. Check or reprocess the file");
    }
    return std::equal(md5_tree, md5_tree + 32, other.md5_tree);
}

bool FingerPrint::TestQueryObjects(const FingerPrint &other) const
{
    if (!other.IsMagicNumberOK())
    {
        throw osrm::exception("missing magic number. Check or reprocess the file");
    }
    return std::equal(md5_objects, md5_objects + 32, other.md5_objects);
}
