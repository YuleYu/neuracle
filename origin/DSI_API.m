function [EEGdata, Timestamp, message] = DSI_API(address, maxDataSize)
%[EEGdata, Timestamp, message] = DSI_API(address, maxDataSize)
%   DSI_API(address, maxDataSize) function is to save the EEG signals from
%   DSI24.
%   address:        target IP address
%   maxDataSize:    the max quantity of data incepted
%   EEGdata:        the incepted EEG data, representd as single-type number
%   Timestamp:      anchored to each row of data, a single-type number represents
%                   the current time
%   message:        some package contain extra cell-type messages
% eg.
%   [EEGdata, Timestamp, message] = DSI_API('192.168.72.139', 10000);
%   

%% Initialize the TCP/IP
cutoffcounter = 0
if address == ' '
    t = tcpip('localhost',8844);
else
    t = tcpip(address, 8844);
end

fclose(t);
fopen(t);

%% Read the first packet
data = uint8(fread(t, 12))';
data = [data, uint8(fread(t, double(typecast(fliplr(data(7:8)), 'uint16'))))']; 
packetType = data(6);

%% The TCPIP Reading Loops
notDone = 1; 
lengthdata = length(data);

indexData = 1;
indexMsg = 1;

while notDone  && (indexData <= maxDataSize)
    i = 1; % i is a counter for 1-byte integers, starting at 1.
    while i <= (lengthdata - 5) 
        while ~((data(i) == 64) && (data(i+1) == 65) && (data(i+2) == 66) && (data(i+3) == 67)) && (i <= lengthdata - 4)
            i = i + 1; 
        end
        if (data(i) == 64) && (data(i+1) == 65) && (data(i+2) == 66) &&  (data(i+3) == 67)  % '@ABCD'
            packetType = data(i+5); % this determines whether it's an event or sensor packet.
            %% Event Packet. Including the greeting packet
            if packetType == 5
                nodeId = typecast(fliplr(data(i+16:i+19)), 'uint32');
                message{indexMsg,1} = nodeId; 
                if ((typecast(fliplr(data(13:16)), 'uint32') ~= 2) &&  (typecast(fliplr(data(13:16)), 'uint32') ~=3))
                    messagelength = typecast(fliplr(data(i+20:i+23)), 'uint32');
                    message{indexMsg,2} = char(data(i+24:i+23+messagelength)) ;
                    indexMsg = indexMsg + 1;
                elseif (typecast(fliplr(data(13:16)), 'uint32')) == 2
                    disp('Here is the start of the data.')
                else
                    disp('The data has ended.')
                end
            end
            %% EEG sensor packet
            if packetType == 1
                Timestamp(indexData) = swapbytes(typecast(data(i+12:i+15),'single'));
                EEGdata(indexData,:) = swapbytes(typecast(data(i+23:i+lengthdata-1),'single'));
                indexData = indexData + 1;
            end
            i = i + 1;
            
        end
        
    end
    %% Termination clause
    if t.Bytesavailable < 12                % if there's not even enough data available to read the header
        cutoffcounter = cutoffcounter + 1;  % take a step towards terminating the whole thing
        if cutoffcounter == 3               % and if 3 steps go by without any new data,
           notDone = 0;                     % terminate the loop.
        end
        disp('no bytes available')
        pause(1)
    else  %meaning, unless there's data available.
        cutoffcounter = 0;
        data = uint8(fread(t, 12))';
        data = [data, uint8(fread(t, double(typecast(fliplr(data(7:8)), 'uint16'))))'];
        notDone = 1;
        lengthdata = length(data);
    end
end
fclose(t);
end