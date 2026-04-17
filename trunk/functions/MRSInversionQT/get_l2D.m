function [Lx,Ly] = get_l2D(n1,n2)

Ax=get_l(n1,1);

%GNA4_new
%for i=1:16; Ax(i,:) = Ax(i,:)*0.1; end
%Ax(16,:) = Ax(16,:)*0; %GNA4 Reflektor 1 @ 0.33m (0.3231m)

%Ax(41,:) = Ax(41,:)*0; %GNA4 Reflektor 2 @ 1.06m (1.0625m)
%Ax(54,:) = Ax(54,:)*0; %GNA4 Reflektor 3 @ 1.70m (1.6904m)
%Ax(77,:) = Ax(77,:)*0; %GNA4 Reflektor 4 @ 3.62m (3.6472m)
%for i=77:80; Ax(i,:) = Ax(i,:)*0.1; end

%Ax(81,:) = Ax(81,:)*0; %GNA4 Reflektor 2 @ 4.14m (4.1579m)
%Ax(70,:) = Ax(70,:)*0; %GNA4 Reflektor13 @ 2.90m (2.8961m)
%
%Ax(92,:) = Ax(92,:)*0; %GNA4

%Ax(52,:) = Ax(52,:)*0; %GNA4
%Ax(76,:) = Ax(76,:)*0; %GNA4
%}

%GNA2
%{
Ax(15,:) = Ax(15,:)*0; %GNA2 Reflektor 1 @ 0.27m
Ax(42,:) = Ax(42,:)*0; %GNA2 Reflektor 2 @ 1.06m
%Ax(49,:) = Ax(49,:)*0; %GNA2 Reflektor 3 @ 1.34m
Ax(65,:) = Ax(65,:)*0; %GNA2 Reflektor 4 @ 2.23m
%for i=1:15; Ax(i,:) = Ax(i,:)*0.1; end
%for i=65:69; Ax(i,:) = Ax(i,:)*0.1; end
%}

%GNA1
%for i=1:23; Ax(i,:) = Ax(i,:)*0.05; end
%Ax(13,:) = Ax(13,:)*0; %GNA1
%Ax(23,:) = Ax(23,:)*0; %GNA1
%}


Bx=eye(n2);
%Lx=full(kron(Bx,Ax));
Ax(size(Ax,2),:) = 0; %square
Lx=kron(Bx,Ax);

Ay=eye(n1);
By=get_l(n2,1);
%Ly=full(kron(By,Ay));
By(size(By,2),:) = 0; %square
Ly=kron(By,Ay);