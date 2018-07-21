function  decryption(image)
%This function takes in an image and will attempt to reconstruct a
%message that is hidden in the image's bits.  It checks the least
%significant bit of each pixel in the image, and pieces them together in
%order to reconstruct the .txt or .wav files that were previously hidden.
%   INPUTS:
%       This function needs to operate on images that have not been
%       compressed since being encoded.  That means it can take in the name
%       of a .bmp file in the directory, or it can take an image that has
%       already been imported and processed in matlab (a previous output)

%%Input Control
%Make sure we have the correct number of inputs
if nargin ~= 1 
    error('Please input solely the name of your image file.');
end

%Make sure we actually got an image to decode.  If we have a 3 dimensional
%array, assume we passed in a processed image.  Otherwise try to import a
%jpg or png file as our image
if(max(size(size(image))) == 3)
    disp('We are assuming this array is a standard image.  Please do not make me regret that')
elseif length(image) < 5 || ~any(all(image(end-3:end) == '.bmp'))
    error('We can only get meaningful data from .bmp image files. Name them accordingly.');
else
    %If we have to import an image from a text file, read it in.
    image = imread(image);
end

%%We will now begin to decode the image.  We will do this by reversing the
%%encoding process.  We permute the image, then take byes of information
%%and store it in a decoded array.  Which we will manipulate after reading
%%the entire image.
permedIm = permute(image, [3 1 2]);

%If this image has a message hidden in it, the first hidden chars should
%indicate how many bytes the message is.  We will assume that no message
%of more than 9,999,999 characters will be hidden in an image.  As such we
%will decode the first 8 characters, or 64 bits in order to see if we can
%find the max.  If we cannot, we'll assume there is no message

%default every bit to be a zero
message = char(ones(8,8)*48);
periodIndex = 0;
for h = 1:65
    %If the bit at my index is a one, set the appropriate bit in my message
    if(bitand(permedIm(h),1))
        message(floor((h-1)/8)+1,mod(h-1,8)+1) = '1';
    end
    if(mod(h-1,8)==0 && h ~= 1)
       if(char(bin2dec(message((h-1)/8,:))) == '.')
          periodIndex =  (h-1)/8;
       end
    end
end
if(periodIndex == 0)
   error('We did not read a message length. So there are probably no messages in this image'); 
end
%Message length is given by the concatenation of the chars we've now
%deciphered.  Add in the number of bytes we used to gain this information
rows = str2num(char(bin2dec(message(1:periodIndex-1,:)))')+(periodIndex - 1);

%Initialize the bytes needed to hold the remaining portion of the message
message = [message; char(ones((rows - size(message,1) ),8)*48)];

bitsToDecode = max(cumprod(size(message)));

%Take the transpose of the message to make it easier to decode
messageTranspose = message';
%We will be decoding one byte at a time
%Go through the image from index 1 until the entire message is hidden
for k = h:bitsToDecode 
    %The hidden bit will be the LSB of the current frame.  Index message
    %the same way we did while encoding, but this time assign to that
    %location 
    if(bitand(permedIm(k),1))
        %I used to use this method to encode/decode, but it is
        %significantly more complicated than it needed to be
        %message(floor((k-1)/8)+1,mod(k-1,8)+1) = '1';
        messageTranspose(k) = '1';
    end
end
message = messageTranspose';

%Once we have the full message, trim out the length from the message
message = message(periodIndex + 1:rows,:);

%%Now that we have extracted a set of binary chars from the message, we
%%just need to turn it back into the message we originally typed in.
%%The first thing we have will be the name of the file regardless of our
%%input. So translate those chars one at a time before doing any other sort
%%of interpretation.

%Create an int to index the message, and a char holder
m = 1;
currentChar = 'a';
fileName = [];
while(currentChar ~= '.')
    currentChar = bin2dec(message(m,:));
    fileName = [fileName currentChar];
    m = m + 1;
    if(m > length(message))
        error('We never found a file name.  Odds are there is no message')
    end
end
%Once we have found a period, the next three chars should indicate the file
%type. Pull them out.
fileType = zeros(1,3);
for n = 0:2
    fileType(n+1) = bin2dec(message(m+n,:));
end
fileName = char([fileName fileType]);
disp('We have found a file!  It is named')
disp(fileName)

%%Now that we know what type of message we are meant to be reading, we can
%%continue reading and interpreting everything else.
message = message(n + m +1:end,:);

%If we have a text message, the decoding process can continue with no
%further changes.
if all(fileType == 'txt')
    %Transform all of the remaining binary numbers back into characters
    message = char(bin2dec(message(:,:)))';
    %Prompt the user for an output type and act accordingly
    outputType = promptUser;
    if(outputType == 1)
        fileID = fopen(fileName,'w');
        fprintf(fileID,message);
        fclose(fileID);
    elseif(outputType == 2)
        disp(message)
    else
        disp(message)
        fileID = fopen(fileName,'w');
        fprintf(fileID,message);
        fclose(fileID);
    end
%Decrypt the file if it is a wav audio file.
elseif(all(fileType == 'wav'))
    %We have one last set of chars hidden in the image.  We need to remove
    %the sampleRate before we can continue processing the image.  This
    %means we need to hunt for one last period in the image.
    %Create an int to index the message, and a char holder
    p = 1;
    currentChar = 'a';
    sampleRate = [];
    while(currentChar ~= '.')
        currentChar = bin2dec(message(p,:));
        sampleRate = [sampleRate currentChar];
        p = p + 1;
        if(p > length(message))
            error('We never found a sample rate.  Someone clearly messed up')
        end
    end
    sampleRate = str2num(char(sampleRate(1:end-1)));
    
    %Trim off the remainder of the message
    message = message(p+n+m:end,:);
    
    %When we encoded the sound files, We had to restructure 64bit numbers
    %to be 8 8 bit numbers instead.  The first thing we need to do to the
    %message is reshape it a second time.
    message = reshape(message',64,max(cumprod(size(message)))/64)';
    
    %We now need to go to each line in the message and convert it back into
    %a float by calling the bin2float function
    floatMessage = double(ones(size(message,1),1));
    for g = 1:size(message,1)
        floatMessage(g) = bin2float(message(g,:));
    end
    
    %Now we have the final message.  We now ask the user how they would
    %like the message to be output.
    outputType = promptUser;
    if(outputType == 1)
        audiowrite(fileName,floatMessage,sampleRate)
    elseif(outputType == 2)
        sound(floatMessage,sampleRate)
    else
        sound(floatMessage,sampleRate)
        audiowrite(fileName,floatMessage,sampleRate)
    end
    
end
end

%We will be asking the user whether or not they want us to give the message
%in Matlab, save it for later viewing, or both.  Since this happens
%regardless of fileType it makes sense to make it an independant function
function response = promptUser()
    response = input(['How would you like your message?' ...
                      '\nEnter 1 to save the file to the directory' ...
                      '\nEnter 2 to recieve the message in the terminal' ...
                      '\nEnter 3 to do both\n']);
    if((response ~= 1) && (response ~= 2) && (response ~= 3))
       disp('That was an invalid input')
       response = promptUser;
    end

end

function f = bin2float(b)
%This function converts a binary number to a floating point number.
%Because hex2num only converts from hex to double, this function will only
%work with double-precision numbers.
%
%Input: b - string of "0"s and "1"s in IEEE 754 floating point format
%Output: f - floating point double-precision number
%
%Floating Point Binary Format
%Double: 1 sign bit, 11 exponent bits, 52 significand bits
%
%Programmer: Eric Verner
%Organization: Matlab Geeks
%Website: matlabgeeks.com
%Email: everner@matlabgeeks.com
%Date: 22 Oct 2012
%
%I allow the use and modification of this code for any purpose.

    %Input checking
    if ~ischar(b)
      disp('Input must be a character string.');
      return;
    end

    hex = '0123456789abcdef'; %Hex characters

    bins = reshape(b,4,numel(b)/4).'; %Reshape into 4x(L/4) character array

    nums = bin2dec(bins); %Convert to numbers in range of (0-15)

    hc = hex(nums + 1); %Convert to hex characters

    f = hex2num(hc); %Convert from hex to float
end