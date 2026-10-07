export type Language='pseint'|'python'|'javascript'|'c';
export type Room={id:string;owner_id:string;name:string;description:string;archived:boolean;join_code:string;created_at:string};
export type Profile={id:string;display_name:string};
export type Membership={room_id:string;user_id:string;display_name:string;joined_at:string};
export type Assignment={id:string;room_id:string;title:string;description:string;starter_code:string;source_language:Language;language:Language;published:boolean;due_at:string|null;created_at:string};
export type Submission={assignment_id:string;student_id:string;source:string;source_language:Language;language:Language;status:'draft'|'submitted';submitted_at:string|null;updated_at:string};
export type Review={assignment_id:string;student_id:string;score:number;feedback:string;updated_at:string};
