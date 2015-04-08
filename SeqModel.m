classdef SeqModel < handle
    properties
        m_fName
        seqFile
    end
    %singleton: only one SeqModel instance but you can change the seqfile 
    methods(Static)                                     
        function obj = getSeqFileInstance(fName)         %Static API
            persistent localObj                          %Persistent Local obj
            if nargin == 1
                if isempty(localObj)|| -isvalid(localObj)
                    localObj = SeqModel(fName);
                    obj = localObj;
                else
                    localObj.seqFile.close();            %I am not sure!!!! 
                    localObj.seqFile = seqIo( fName, 'r' );
                    obj = localObj;                      %if obj already exist,return the instance
                end
            elseif isempty(localObj)|| -isvalid(localObj)
                    error('fName required!');
                else
                    obj = localObj;
            end
        end
        
    end
    
    methods(Access = private)
        function obj = SeqModel(fName)
            if nargin == 1 
            obj.seqFile = seqIo( fName, 'r' );
            else
                return
            end
        end

    end
    methods
        function delete(obj)
            obj.seqFile.close();                                %release the memory
        end
    end
    
end

