classdef testObj2struct < matlab.unittest.TestCase
    
    properties
        default_opts = struct(...
            'IncludeHidden', true, ...
            'IncludeTransient', true, ...
            'IncludeDependent', true, ...
            'MaxDepth', 100);
    end
    
    methods(TestMethodSetup)
        function addHelpersToPath(testCase)
            testFile = which('testObj2struct');
            currentFolder = fileparts(testFile);
            helperFolder = fullfile(currentFolder, 'testObj2struct_classes');
            addpath(helperFolder);
        end
    end
    
    methods(Test)
        
        %% Test 1: Basic Conversion
        function testBasicConversion(testCase)
            obj = SimpleClass;
            obj.PropA = 123;
            obj.PropB = "Hello";
            
            S = obj2struct(obj, testCase.default_opts, 0, {}, {});
            
            testCase.verifyTrue(isstruct(S));
            testCase.verifyEqual(S.class, 'SimpleClass');
            testCase.verifyEqual(S.PropA, 123);
            testCase.verifyEqual(S.PropB, "Hello");
        end
        
        %% Test 2: Attribute Filtering
        function testAttributeFiltering(testCase)
            obj = AttributeClass;
            
            % 1. Default (all true)
            S_all = obj2struct(obj, testCase.default_opts, 0, {}, {});
            testCase.verifyTrue(isfield(S_all, 'PublicProp'));
            testCase.verifyTrue(isfield(S_all, 'HiddenProp'));
            testCase.verifyTrue(isfield(S_all, 'TransientProp'));
            testCase.verifyTrue(isfield(S_all, 'DependentProp'));
            
            % 2. Exclude Hidden
            opts_noHidden = testCase.default_opts;
            opts_noHidden.IncludeHidden = false;
            S_noHidden = obj2struct(obj, opts_noHidden, 0, {}, {});
            testCase.verifyTrue(isfield(S_noHidden, 'PublicProp'));
            testCase.verifyTrue(~isfield(S_noHidden, 'HiddenProp'));
            
            % 3. Exclude Transient
            opts_noTransient = testCase.default_opts;
            opts_noTransient.IncludeTransient = false;
            S_noTransient = obj2struct(obj, opts_noTransient, 0, {}, {});
            testCase.verifyTrue(isfield(S_noTransient, 'PublicProp'));
            testCase.verifyTrue(~isfield(S_noTransient, 'TransientProp'));
            
            % 4. Exclude Dependent
            opts_noDependent = testCase.default_opts;
            opts_noDependent.IncludeDependent = false;
            S_noDependent = obj2struct(obj, opts_noDependent, 0, {}, {});
            testCase.verifyTrue(isfield(S_noDependent, 'PublicProp'));
            testCase.verifyTrue(~isfield(S_noDependent, 'DependentProp'));
        end
        
        %% Test 3: MaxDepth
        function testMaxDepth(testCase)
            obj = NestedOuter;
            obj.Inner = NestedInner;
            obj.Inner.Value = 200;
            
            % Test 1: MaxDepth = 0
            opts_depth0 = testCase.default_opts;
            opts_depth0.MaxDepth = 0;
            S_depth0 = obj2struct(obj, opts_depth0, 0, {}, {});
            
            testCase.verifyTrue(isfield(S_depth0, 'Inner'));
            testCase.verifyTrue(isstruct(S_depth0.Inner));
            testCase.verifyEmpty(fieldnames(S_depth0.Inner), 'Inner struct should be empty at MaxDepth 0');
            
            % Test 2: MaxDepth = 1
            opts_depth1 = testCase.default_opts;
            opts_depth1.MaxDepth = 1;
            S_depth1 = obj2struct(obj, opts_depth1, 0, {}, {});
            
            testCase.verifyTrue(isfield(S_depth1, 'Inner'));
            testCase.verifyTrue(isfield(S_depth1.Inner, 'Name'));
            testCase.verifyEqual(S_depth1.Inner.Name, "Inner");
            testCase.verifyTrue(isfield(S_depth1.Inner, 'Value'));
            testCase.verifyEqual(S_depth1.Inner.Value, 200);
        end
        
        %% Test 4: Circular Reference
        function testCircularReference(testCase)
            objA = CircularA;
            objB = CircularB;
            
            objA.B = objB;
            objB.A = objA; % A -> B -> A
            
            S = obj2struct(objA, testCase.default_opts, 0, {}, {});
            
            testCase.verifyTrue(isfield(S.B.A, 'circular'));
            testCase.verifyTrue(S.B.A.circular);
            testCase.verifyEqual(S.B.A.class, 'CircularA');
        end
        
        %% Test 5: Simple Property Filter
        function testSimplePropertyFilter(testCase)
            obj = AttributeClass;
            filter = {"PublicProp", "HiddenProp"};
            
            S = obj2struct(obj, testCase.default_opts, 0, {}, filter);
            
            testCase.verifyTrue(isfield(S, 'class')); % 'class' is always added
            testCase.verifyTrue(isfield(S, 'PublicProp'));
            testCase.verifyTrue(isfield(S, 'HiddenProp'));
            testCase.verifyTrue(~isfield(S, 'TransientProp'));
            testCase.verifyTrue(~isfield(S, 'DependentProp'));
        end
        
        %% Test 6: Nested Property Filter
        function testNestedPropertyFilter(testCase)
            obj = NestedOuter;
            obj.Inner = NestedInner;
            
            % We want: Outer 'Name'
            % We want: Outer 'Inner' object
            % We *only* want: Inner 'Value' (not Inner 'Name')
            filter = {"Name", {"Inner", {"Value"}}};
            
            S = obj2struct(obj, testCase.default_opts, 0, {}, filter);
            
            testCase.verifyTrue(isfield(S, 'Name'));
            testCase.verifyEqual(S.Name, "Outer");
            testCase.verifyTrue(isfield(S, 'Inner'));
            testCase.verifyTrue(isfield(S.Inner, 'Value'));
            testCase.verifyEqual(S.Inner.Value, 100);
            testCase.verifyTrue(~isfield(S.Inner, 'Name'));
        end
        
        %% Test 7: Filter With Attribute Exclusion
        function testFilterAttributeExclusion(testCase)
            obj = AttributeClass;
            filter = {"PublicProp", "HiddenProp"}; % Try to include 'HiddenProp'
            
            % But explicitly exclude it with opts
            opts_noHidden = testCase.default_opts;
            opts_noHidden.IncludeHidden = false;
            
            S = obj2struct(obj, opts_noHidden, 0, {}, filter);
            
            testCase.verifyTrue(isfield(S, 'PublicProp'));
            testCase.verifyTrue(~isfield(S, 'HiddenProp'));
        end
        
        %% Test 8: Non-Object Types
        function testNonObjectTypes(testCase)
            % 1. Cell Array
            c_obj = SimpleClass;
            c = {1, "test", c_obj};
            S_cell = obj2struct(c, testCase.default_opts, 0, {}, {});
            
            testCase.verifyTrue(iscell(S_cell));
            testCase.verifyEqual(S_cell{1}, 1);
            testCase.verifyEqual(S_cell{2}, "test");
            testCase.verifyEqual(S_cell{3}.PropA, 1);
            
            % 2. containers.Map
            m_obj = SimpleClass;
            m = containers.Map;
            m('key1') = 42;
            m('key2') = m_obj;
            m('invalid-key') = 100; % Will be renamed
            
            S_map = obj2struct(m, testCase.default_opts, 0, {}, {});
            testCase.verifyTrue(isstruct(S_map));
            testCase.verifyEqual(S_map.key1, 42);
            testCase.verifyEqual(S_map.key2.PropB, "hello");
            testCase.verifyTrue(isfield(S_map, 'invalid_key'));
            testCase.verifyEqual(S_map.invalid_key, 100);
            
            % 3. Plain Struct
            st_obj = SimpleClass;
            st.a = 1;
            st.b = st_obj;
            
            S_struct = obj2struct(st, testCase.default_opts, 0, {}, {});
            testCase.verifyTrue(isstruct(S_struct));
            testCase.verifyEqual(S_struct.a, 1);
            testCase.verifyEqual(S_struct.b.PropA, 1);
            
            % 4. Array of Objects
            obj1 = SimpleClass;
            obj2 = SimpleClass;
            obj2.PropA = 99;
            obj_array = [obj1, obj2];
            
            S_array = obj2struct(obj_array, testCase.default_opts, 0, {}, {});
            testCase.verifyTrue(isstruct(S_array));
            testCase.verifyEqual(numel(S_array), 2);
            testCase.verifyEqual(S_array(1).PropA, 1);
            testCase.verifyEqual(S_array(2).PropA, 99);
            testCase.verifyEqual(S_array(1).class, 'SimpleClass');
        end
        
    end
    
end