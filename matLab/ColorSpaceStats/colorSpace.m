classdef colorSpace
    %UNTITLED Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        sigma; sig; g; c; uC; uT;
        sMin; sMax; sRange;
        dMin; dMax; dRange;
        ErfA; ErfB; ErfAB;
        shift; scale; sUnitGrad; sLowHigh; dUnitGrad;
        linearConstant; shiftednErfConstant; dMaxShifted;
        cubeSkin;
    end
    
    methods
        function obj = colorSpace(theta, c, sigma, sig, sMin, sMax, dMin, dMax, cubeSkin, cInSrc)
            if nargin>=6
                obj.sMin = sMin; obj.sMax = sMax; obj.sRange = (sMax - sMin);
                if nargin>=8
                    obj.dMin = dMin; obj.dMax = dMax; obj.dRange = (dMax - dMin);
                else
                    obj.dMin = 0; obj.dMax = 255; obj.dRange = 255;
                end
            else
                obj.sMin = 0; obj.sMax = 255; obj.sRange = 255;
            end
            
            if nargin>=9
                obj.cubeSkin = cubeSkin;
            else
                obj.cubeSkin = 0;
            end
            
            if nargin>=4
                obj.sig = sig; obj.sigma = sigma;
                obj.g = [ obj.sRange./(sqrt(2) .* sig(1) .* sigma(1)), obj.sRange./(sqrt(2) .* sig(2) .* sigma(2)), obj.sRange./(sqrt(2) .* sig(3) .* sigma(3))];
            end
            
            if nargin>=1
                obj.uT = transformationMatrixLAB(theta);
            end
            
            if cInSrc && nargin==10
                obj.uC = obj.srcToUnit(c) * obj.uT' + [0, 0.5, 0.5];
            else
                obj.uC = obj.dstToUnit(c );
            end
            
            obj.c = obj.unitToDst( obj.uC);
            obj.ErfA = erf(obj.g .* obj.uC );
            obj.ErfB = erf(obj.g .* (1. - obj.uC));
            obj.ErfAB = obj.ErfB + obj.ErfA;
            obj.shift = obj.unitToDst(obj.ErfA ./ obj.ErfAB);
            obj.scale = obj.dRange ./ obj.ErfAB;
            obj.sUnitGrad = [floor(obj.c - (obj.sRange .* sqrt(log((2*obj.dRange .* obj.g)./(obj.ErfAB .* sqrt(pi) .* obj.sRange))))./obj.g); ...
                ceil(obj.c + (obj.sRange .* sqrt(log((2*obj.dRange .* obj.g)./(obj.ErfAB .* sqrt(pi) .* obj.sRange))))./obj.g)];
            ull = 1/obj.dRange;
            uul = (obj.dRange - 1)./obj.dRange;
            obj.sLowHigh = [obj.c + obj.sRange .* erfinv(ull*obj.ErfB-uul*obj.ErfA)./obj.g; ...
                obj.c - obj.sRange .* erfinv(ull*obj.ErfA-uul*obj.ErfB)./obj.g];
            
            obj.dUnitGrad(1,:) = obj.shift(:) + obj.scale(:) .* erf( obj.g(:) .* (obj.sUnitGrad(1,:)' - obj.c(:)) ./ obj.sRange);
            obj.dUnitGrad(2,:) = obj.shift(:) + obj.scale(:) .* erf( obj.g(:) .* (obj.sUnitGrad(2,:)' - obj.c(:)) ./ obj.sRange);
            
            obj.linearConstant = obj.dUnitGrad(1,:) - obj.sUnitGrad(1,:);
            obj.shiftednErfConstant = obj.sUnitGrad(2,:) + obj.dUnitGrad(1,:) - obj.sUnitGrad(1,:) - obj.dUnitGrad(2,:);
            obj.dMaxShifted = (obj.dMax + obj.shiftednErfConstant')';
            
        end % function
        
        function obj = setTheta(theta)
            obj.uT = transformationMatrixLAB(theta);
        end % function
        
        function outImage = toScaled(obj, img)
            [rows, cols, chans] = size(img);
            %# First convert the RGB image to double precision
            outImage = reshape(double(img),[],chans);
            %# Apply the rescaling function
            for i=1:rows*cols
                outImage(i,:) = obj.scaledPoint(outImage(i,:));
            end
            %# Convert back to type uint8 and reshape to its original size:
            outImage = reshape(uint8(outImage),size(img));
        end % function
        
        function outImage = toCompactScaled(obj, img)
            [rows, cols, chans] = size(img);
            %# First convert the RGB image to double precision
            outImage = reshape(double(img),[],chans);
            %# Apply the rescaling function
            for i=1:rows*cols
                outImage(i,:) = obj.compactScaledPoint(outImage(i,:));
            end
            %# Convert back to type uint8 and reshape to its original size:
            outImage = reshape(uint8(outImage),size(img));
        end % function
        
        function outImage = toRot(obj, img)
            [rows, cols, chans] = size(img);
            %# First convert the RGB image to double precision
            uImage = reshape(double(img)./obj.sRange,[],3);
            uRotImage = uImage * obj.uT';
            %# Shift each color plane (stored in each column of the N-by-3 matrix):
            uRotImage(:,1) =  uRotImage(:,1);
            uRotImage(:,2) = (uRotImage(:,2) + 0.5);
            uRotImage(:,3) = (uRotImage(:,3) + 0.5);
            %# Convert back to type uint8 and reshape to its original size:
            outImage = reshape(uint8(uRotImage.* obj.dRange + obj.dMin), [rows, cols, chans]);
        end % function
        
        
        function outImage = toRotScaled(obj, img)
            
            [rows, cols, chans] = size(img);
            
            uImage = reshape(double(img)./obj.sRange,[],3);
            uRotImage = uImage * obj.uT';
            %# Shift each color plane (stored in each column of the N-by-3 matrix):
            uRotImage(:,1) =  uRotImage(:,1);
            uRotImage(:,2) = (uRotImage(:,2) + 0.5);
            uRotImage(:,3) = (uRotImage(:,3) + 0.5);
            %# Apply the rescaling function
            scaledImage = zeros(size(uRotImage));
            for i=1:rows*cols
                scaledImage(i,:) = obj.scaledPoint(obj.dRange.*uRotImage(i,:) +obj.dMin);
            end
            %# Shift each color plane (stored in each column of the N-by-3 matrix):
            % scaledImage(:,1) = obj.shift(1) + obj.scale(1) * erf( obj.g(1) * (uRotImage(:,1) - obj.uC(1)) );
            % scaledImage(:,2) = obj.shift(2) + obj.scale(2) * erf( obj.g(2) * (uRotImage(:,2) - obj.uC(2)) );
            % scaledImage(:,3) = obj.shift(3) + obj.scale(3) * erf( obj.g(3) * (uRotImage(:,3) - obj.uC(3)) );
            %# Convert back to type uint8 and reshape to its original size:
            outImage = reshape(uint8(scaledImage),[rows, cols, chans]);
            
        end % function
        
        function outImage = toRotCompactScaled(obj, img)
            
            [rows, cols, chans] = size(img);
            
            uImage = reshape(double(img)./obj.sRange,[],3);
            uRotImage = uImage * obj.uT';
            %# Shift each color plane (stored in each column of the N-by-3 matrix):
            uRotImage(:,1) =  uRotImage(:,1);
            uRotImage(:,2) = (uRotImage(:,2) + 0.5);
            uRotImage(:,3) = (uRotImage(:,3) + 0.5);
            %# Apply the rescaling function
            scaledImage = zeros(size(uRotImage));
            for i=1:rows*cols
                scaledImage(i,:) = obj.compactScaledPoint(obj.dRange.*uRotImage(i,:) +obj.dMin);
            end
            %# Shift each color plane (stored in each column of the N-by-3 matrix):
            % scaledImage(:,1) = obj.shift(1) + obj.scale(1) * erf( obj.g(1) * (uRotImage(:,1) - obj.uC(1)) );
            % scaledImage(:,2) = obj.shift(2) + obj.scale(2) * erf( obj.g(2) * (uRotImage(:,2) - obj.uC(2)) );
            % scaledImage(:,3) = obj.shift(3) + obj.scale(3) * erf( obj.g(3) * (uRotImage(:,3) - obj.uC(3)) );
            %# Convert back to type uint8 and reshape to its original size:
            outImage = reshape(uint8(scaledImage),[rows, cols, chans]);
            
        end % function
        
        function outImage = toProbability(obj, img)
            
            [rows, cols, chans] = size(img);
            
            uImage = reshape(double(img)./obj.sRange,[],3);
            uRotImage = uImage * obj.uT';
            %# Shift each color plane (stored in each column of the N-by-3 matrix):
            uRotImage(:,1) =  uRotImage(:,1);
            uRotImage(:,2) = (uRotImage(:,2) + 0.5);
            uRotImage(:,3) = (uRotImage(:,3) + 0.5);
            
            uProb = zeros(rows * cols, 2);
            uProb(:,1) = uImage(:,1)<(obj.sMax-obj.cubeSkin)/obj.sMax & uImage(:,2)<(obj.sMax-obj.cubeSkin)/obj.sMax & uImage(:,3)<(obj.sMax-obj.cubeSkin)/obj.sMax & uImage(:,1)>(obj.cubeSkin + obj.sMin)/obj.sMax & uImage(:,2)>(obj.cubeSkin + obj.sMin)/obj.sMax & uImage(:,3)>(obj.cubeSkin + obj.sMin)/obj.sMax;
            uProb(:,2) = 1. ./ ( exp((uRotImage(:,2) - obj.uC(2)).^2 ./ ( 2. * (obj.sig(2) * obj.sigma(2)/obj.sRange)^2)) .* exp((uRotImage(:,3) - obj.uC(3)).^2 ./ ( 2. * (obj.sig(3) * obj.sigma(3)/obj.sRange)^2)));
            
            %# Convert back to type uint8 and reshape to its original size:
            outImage = reshape(horzcat(uint8(uImage.* obj.dRange),uint8(scaledImage),uint8(uProb.* obj.dRange)),[rows, cols, chans+5]);
            
        end % function
        
        function outImage = toTotal(obj, img)
            
            [rows, cols, chans] = size(img);
            
            uImage = reshape(double(img)./obj.sRange,[],3);
            uRotImage = uImage * obj.uT';
            %# Shift each color plane (stored in each column of the N-by-3 matrix):
            uRotImage(:,1) =  uRotImage(:,1);
            uRotImage(:,2) = (uRotImage(:,2) + 0.5);
            uRotImage(:,3) = (uRotImage(:,3) + 0.5);
            %# Apply the rescaling function
            scaledImage = zeros(size(uRotImage));
            compactScaledImage = zeros(size(uRotImage));
            for i=1:rows*cols
                scaledImage(i,:) = obj.compactScaledPoint(obj.dRange.*uRotImage(i,:) +obj.dMin);
                compactScaledImage(i,:) = obj.scaledPoint(obj.dRange.*uRotImage(i,:) +obj.dMin);
            end
            
            uProb = zeros(rows * cols, 2);
            uProb(:,1) = uImage(:,1)<(obj.sMax-obj.cubeSkin)/obj.sMax & uImage(:,2)<(obj.sMax-obj.cubeSkin)/obj.sMax & uImage(:,3)<(obj.sMax-obj.cubeSkin)/obj.sMax & uImage(:,1)>(obj.cubeSkin + obj.sMin)/obj.sMax & uImage(:,2)>(obj.cubeSkin + obj.sMin)/obj.sMax & uImage(:,3)>(obj.cubeSkin + obj.sMin)/obj.sMax;
            uProb(:,2) = 1. ./ ( exp((uRotImage(:,2) - obj.uC(2)).^2 ./ ( 2. * (obj.sig(2) * obj.sigma(2)/obj.sRange)^2)) .* exp((uRotImage(:,3) - obj.uC(3)).^2 ./ ( 2. * (obj.sig(3) * obj.sigma(3)/obj.sRange)^2)));
            
            %# Convert back to type uint8 and reshape to its original size:
            outImage = reshape(horzcat(uint8(uImage.* obj.dRange + obj.dMin),uint8(scaledImage),uint8(compactScaledImage),uint8(uProb.* obj.dRange + obj.dMin)),[rows, cols, chans*4]);
            
        end % function
        
        function pixelOut = compactScaledPoint(obj, point)
            pixelOut = zeros(size(point));
            for i=1:length(point)
                if point(i) < obj.sLowHigh(1,i)
                    pixelOut(i) = obj.dMin;
                elseif obj.sLowHigh(1,i) < point(i) <= obj.dUnitGrad(1,i)
                    pixelOut(i) = obj.scaledPoint(point(i));
                elseif obj.dUnitGrad(1,i) < point(i) <= obj.dUnitGrad(2,i)
                    pixelOut(i) = pixelOut(i) + obj.linearConstant;
                elseif obj.dUnitGrad(2,i) < point(i) <= obj.sLowHigh(2,i)
                    pixelOut(i) = obj.scaledPoint(point(i)) + obj.shiftednErfConstant;
                elseif obj.sLowHigh(2,i) < point(i)
                    pixelOut(i) = obj.dMaxShifted;
                end
            end
        end % function
        
        function pixelOut = scaledPoint(obj, point)
            pixelOut = zeros(size(point));
            for i=1:length(point)
                pixelOut(i) = obj.shift(i) + obj.scale(i) * erf( obj.g(i) * (point(i) - obj.c(i)) ./ obj.sRange );
            end
        end % function
        
        function unit = srcToUnit(obj, point)
            unit = (point - obj.sMin)./obj.sRange;
        end % function
        
        function unit = dstToUnit(obj, point)
            unit = (point - obj.dMin)./obj.dRange;
        end % function
        
        function src = unitToSrc(obj, point)
            src = point.*obj.sRange + obj.sMin;
        end % function
        
        function dst = unitToDst(obj, point)
            dst = point.*obj.dRange + obj.dMin;
        end % function
        
    end
    
end
