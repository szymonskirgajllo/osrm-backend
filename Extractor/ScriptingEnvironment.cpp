/*
 open source routing machine
 Copyright (C) Dennis Luxen, others 2010

 This program is free software; you can redistribute it and/or modify
 it under the terms of the GNU AFFERO General Public License as published by
 the Free Software Foundation; either version 3 of the License, or
 any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU Affero General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 or see http://www.gnu.org/licenses/agpl.txt.
 */

#include "ScriptingEnvironment.h"
#include "../DataStructures/LuaRouteIterator.h"

ScriptingEnvironment::ScriptingEnvironment(const char * fileName) {
	INFO("Using script " << fileName);

    // Create a new lua state
    for(int i = 0; i < omp_get_max_threads(); ++i) {
        INFO("pushing lua state");
        luaStateVector.push_back(luaL_newstate());
    }
    
    // Connect LuaBind to this lua state for all threads
#pragma omp parallel
    {
        lua_State * myLuaState = getLuaStateForThreadID(omp_get_thread_num());
        luabind::open(myLuaState);
        //open utility libraries string library;
        luaL_openlibs(myLuaState);

        luaAddScriptFolderToLoadPath( myLuaState, fileName );

        // Add our function to the state's global scope
        luabind::module(myLuaState) [
                                     luabind::def("print", LUA_print<std::string>),
                                     luabind::def("parseMaxspeed", parseMaxspeed),
                                     luabind::def("durationIsValid", durationIsValid),
                                     luabind::def("parseDuration", parseDuration)
        ];

        luabind::module(myLuaState) [
                                     luabind::class_<HashTable<std::string, std::string> >("keyVals")
                                     .def("Add", &HashTable<std::string, std::string>::Add)
                                     .def("Find", &HashTable<std::string, std::string>::Find)
                                     .def("Holds", &HashTable<std::string, std::string>::Holds)
                                     ];
                            
                            
         luabind::module(myLuaState) [
                                      luabind::class_<ExtractorRoute>("ExtractorRoute")
                                      .def_readwrite("id", &ExtractorRoute::id)
                                      .def_readwrite("tags", &ExtractorRoute::tags)
                                      ];

         luabind::module(myLuaState) [
                                      luabind::class_<LuaRouteIterator>("routes")
                                      .def("Next", &LuaRouteIterator::Next)
                                      ];
                                      
        luabind::module(myLuaState) [
                                     luabind::class_<ImportNode>("Node")
                                     .def(luabind::constructor<>())
                                     .def_readwrite("lat", &ImportNode::lat)
                                     .def_readwrite("lon", &ImportNode::lon)
                                     .def_readwrite("id", &ImportNode::id)
                                     .def_readwrite("bollard", &ImportNode::bollard)
                                     .def_readwrite("traffic_light", &ImportNode::trafficLight)
                                     .def_readwrite("tags", &ImportNode::keyVals)
                                     ];

        luabind::module(myLuaState) [
                                     luabind::class_<ExtractionWay>("Way")
                                     .def(luabind::constructor<>())
                                     .def_readwrite("id", &ExtractionWay::id)
                                     .def_readwrite("name", &ExtractionWay::name)
                                     .def_readwrite("duration", &ExtractionWay::duration)
                                     .def_readwrite("access", &ExtractionWay::access)
                                     .def_readwrite("roundabout", &ExtractionWay::roundabout)
                                     .def_readwrite("is_access_restricted", &ExtractionWay::isAccessRestricted)
                                     .def_readwrite("ignore_in_grid", &ExtractionWay::ignoreInGrid)
                                     .def_readwrite("tags", &ExtractionWay::keyVals)
                                     .def_readwrite("forward", &ExtractionWay::forward)
                                     .def_readwrite("backward", &ExtractionWay::backward)
                                     .property("mode", &ExtractionWay::get_mode, &ExtractionWay::set_mode)
                                     .property("speed", &ExtractionWay::get_speed, &ExtractionWay::set_speed)
        							 ];

         luabind::module(myLuaState) [
                                      luabind::class_<ExtractionWay::SettingsForDirection>("WaySettingsForDirection")
                                      .def_readwrite("speed", &ExtractionWay::SettingsForDirection::speed)
                                      .def_readwrite("mode", &ExtractionWay::SettingsForDirection::mode)
         							 ];

        luabind::module(myLuaState) [
                                     luabind::class_<std::vector<std::string> >("vector")
                                     .def("Add", &std::vector<std::string>::push_back)
                                     ];

        if(0 != luaL_dofile(myLuaState, fileName) ) {
            ERR(lua_tostring(myLuaState,-1)<< " occured in scripting block");
        }
    }
}

ScriptingEnvironment::~ScriptingEnvironment() {
    for(unsigned i = 0; i < luaStateVector.size(); ++i) {
        //        luaStateVector[i];
    }
}

lua_State * ScriptingEnvironment::getLuaStateForThreadID(const int id) {
    return luaStateVector[id];
}
